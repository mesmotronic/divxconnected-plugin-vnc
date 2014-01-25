/*
* ConnectedVNC: A VNC Client for the DivX Connected set-top box
* Copyright (C) 2010 Mesmotronic Limited <www.mesmotronic.com>
*
* ConnectedVNC is based on FVNC, Copyright (C) 2005-2007 Darron 
* Schall <darron@darronschall.com>, modified to work with the 
* DivX Connected SDK (see http://labs.divx.com/connected) and
* adds features such as an on-screen cursor and replaces mouse
* interactivity with mappings to the DivX Connected remote control
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation; either version 2 of the
* License, or (at your option) any later version.
* 
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
* General Public License for more details.
* 
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
* 02111-1307 USA
*/

package connectedvnc
{
	import connectedvnc.rfb.RFBProtocol;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.external.ExternalInterface;
	import flash.filters.DropShadowFilter;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.system.Security;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	import connectedvnc.errors.ConnectionError;
	import connectedvnc.events.ConnectedVNCErrorEvent;
	import connectedvnc.events.ConnectedVNCEvent;
	import connectedvnc.rfb.PixelFormat;
	import connectedvnc.rfb.RFBParser;
	import connectedvnc.rfb.ServerInit;
	import connectedvnc.rfb.constants.AuthenticationStatus;
	import connectedvnc.rfb.constants.Encoding;
	import connectedvnc.rfb.constants.ProtocolState;
	import connectedvnc.rfb.constants.SecurityType;
	import connectedvnc.rfb.tree.RFBServerMessage;
	
	import mx.containers.Canvas;
	import mx.controls.Alert;
	import mx.controls.Image;
	import mx.controls.Label;
	import mx.core.EdgeMetrics;
	import mx.core.UIComponent;
	
	import org.osflash.cryptography.DES;
	
	/** 
	 * Broadcast when the server requires a password to be entered.  Setting
	 * the password property on the FVNC instance will continue the connection
	 * process.
	 * @eventType fvnc.events.FVNCEvent.PASSWORD_REQUIRED
	 */
	[Event(name="passwordRequired", type="connectedvnc.events.ConnectedVNCEvent")]
	
	/** 
	 * Broadcast when password provided is not a valid password.
	 * @eventType fvnc.events.FVNCEvent.INVALID_PASSWORD
	 */
	[Event(name="invalidPassword", type="connectedvnc.events.ConnectedVNCEvent")]
	
	/** 
	 * Broadcast when a connection could not be estabiled with the server.
	 * @eventType fvnc.events.FVNCErrorEvent.CONNECTION_ERROR
	 */
	[Event(name="connectionError", type="connectedvnc.events.ConnectedVNCErrorEvent")]
	
	/**
	 * Broadcast only when the client and server are disconnected.
	 * @eventType flash.events.Event.CLOSE
	 */
	[Event(name="close", type="flash.events.Event")]
	
	[Event(name="connect", type="flash.events.Event")]
	
	/**
	 * 
	 */
	public class ConnectedVNC extends Canvas
	{
		[Embed("assets/cursor.png")] protected var MouseCursor:Class;
		
		/** The intial state of the protocol is not connected */
		private var state:int = ProtocolState.NOT_CONNECTED;
		
		/** The active socket connection to the VNC server. */		
		protected var rfb:RFBProtocol;
		
		/**
		 * Map protocol states the to functions that will _on
		 * the data for the protocol at that particular state
		 */
		protected var statesMap:Object = initializeStatesMap(); 
		
		protected var _mouseDown:Boolean = false;
		protected var _mouseTime:int = 0;
		
		/**
		 * Create the states map object and populate state/_onr mapping.
		 */
		protected function initializeStatesMap():Object
		{
			var statesMap:Object = new Object();
			
			statesMap[ ProtocolState.NOT_CONNECTED 	  ] = handshake;
			statesMap[ ProtocolState.GET_AUTH_SCHEME  ] = authenticate;
			statesMap[ ProtocolState.GET_CHALLENGE    ] = getChallenge;
			statesMap[ ProtocolState.GET_AUTH_RESULT  ] = processAuthResult;
			statesMap[ ProtocolState.READ_SERVER_INIT ] = doInitialization;
			statesMap[ ProtocolState.READ_SERVER_NAME ] = doReadServerName;
			statesMap[ ProtocolState.CONNECTED        ] = parseServerMessages;
			
			return statesMap;
		}
		
		/**
		 * For authentication purposes, we receive a challenge
		 * that we need to provide a response for
		 */
		protected var challenge:ByteArray;
				
		// =====================================
		//  host property
		// =====================================
		
		/** Storage for the host property. */
		private var _host:String;
		
		/**
		 * The host VNC server to connect to. 
		 */
		public function get host():String
		{
			return _host;
		}
		
		public function set host(value:String):void
		{
			checkActiveConnection("host");
			
			_host = value;
			invalidateProperties();
		}
		
		// =====================================
		//  port property
		// =====================================
		
		/** Storage for the port property. */
		private var _port:uint = 5900;
		
		/**
		 * The port over which to connect to the VNC server.  The
		 * default value is 5900.
		 * 
		 * @default 5900
		 */
		public function get port():uint
		{
			return _port;
		}
		
		public function set port(value:uint):void
		{
			checkActiveConnection("port");
			
			_port = value;
			invalidateProperties();
		}
		
		/**
		 * Helper function to check to see if the server is already connected, and throw
		 * an error if so.
		 * 
		 * @param part The part we're trying to change while we're already connected.  Valid
		 * 		values are "port" and "host".
		 */
		private function checkActiveConnection(part:String):void
		{
			if (rfb && rfb.connected)
			{
				throw new Error("Cannot update " + part + " when there is an active VNC connection.  Disconnect first and then try again.");
			}	
		}
		
		// =====================================
		//  password property
		// =====================================
		
		/** Storage for the password property. */
		private var _password:String;
		
		public function set password(value:String):void
		{
			// If we're already connected and we're waiting for the password
			// to be set, then apply the password right away (so we don't store it)
			if (rfb && rfb.connected && state == ProtocolState.GET_AUTH_RESULT)
			{
				applyPassword(value);
			}
			// Setting the password before connecting or before we're ready to
			// send the password to the server.  Save it until we need it then.
			else
			{
				_password = value;
			}
		}
		
		// =====================================
		//  fitToScreen property
		// =====================================
		
		/** Storage for the fitToScreen property. */
		private var _fitToScreen:Boolean;
		protected var fitToScreenChanged:Boolean = false;
		
		/** 
		 * Flag to determine how the remote screen should be drawn.  A <code>true</code> value
		 * will scale the remote screen to display in the given width/height of the component.  A
		 * <code>false</code> value will maintain a 100% scale factor.
		 */
		public function get fitToScreen():Boolean
		{
			return _fitToScreen;
		}
		
		public function set fitToScreen(value:Boolean):void
		{
			_fitToScreen = value;
			fitToScreenChanged = true;
			
			invalidateSize();
			invalidateProperties();
		}
		
		// =====================================
		//  autoConnect property
		// =====================================
		
		/** Storage for the autoConnect property. */
		private var _autoConnect:Boolean = false;
		
		/**
		 * Flag indicating if we should attempt to connect as soon the host
		 * and port are set.  Otherwise, the connect has to be started manually
		 * by invoking the connect method.
		 */
		public function get autoConnect():Boolean
		{
			return _autoConnect;
		}
		
		public function set autoConnect(value:Boolean):void
		{
			_autoConnect = value;
			
			invalidateProperties();
		}
		
		/**
		 * Draw inside screenImageData via lock/unlock instead of
		 * using an onscreen/offscreen bitmap data technique.  This is attached to
		 * screenImage on the DispalyList so things get updated visually.
		 */
		private var screenImage:Bitmap;
		private var screenImageData:BitmapData;
		
		/** The UIComponent to hold the bitmap data for the remote screen. */
		protected var remoteScreen:UIComponent;
				
		/** 
		 * The rectangle that defines the screen bounds to
		 * be used for frame buffer updates.
		 */
		private var screenBounds:Rectangle;
				
		/** 
		 * The RFB Parser for reading the server messages from the asynchronous
		 * socket connection.
		 */
		private var parser:RFBParser;
				
		/** Keep track of our server messages until the next frame / redraw. */
		[ArrayElementType("fvnc.rfb.RFBServerMessage")]
		private var messages:Array;
		
		protected var _mouseCursor:Image;
		
		/**
		 * Constructor 
		 */
		public function ConnectedVNC()
		{
			super();
			
			state = ProtocolState.NOT_CONNECTED;
			rfb = null;
		}
		
		/**
		 * 
		 */
		override protected function commitProperties():void
		{
			super.commitProperties();
			
			// If we have a port and host defined, then automatically connect to the VNC
			// server if the autoConnect flag is also set (and we're not already connected).
			if (rfb && !rfb.connected && port != 0 && host != "" && autoConnect)
			{
				connect();
			}
			
			if (fitToScreenChanged)
			{
				fitToScreenChanged = false;
				trace("TODO: Implement fitToScreenChanged code in commitProperties.");
			}
		}
		
		/**
		 * 
		 */
		override protected function createChildren():void
		{
			super.createChildren();
			
			if (!remoteScreen)
			{
				remoteScreen = new UIComponent();
				remoteScreen.tabEnabled = true;
				addChild(remoteScreen);
			}
			
			if (!_mouseCursor)
			{
				_mouseCursor = new Image;
				_mouseCursor.source = MouseCursor;
				_mouseCursor.filters = [new DropShadowFilter(2, 45, 0, 0.75, 6, 6, 1, 3)];
				
				//addChild(_mouseCursor);
			}
		}
		
		/**
		 * 
		 */
		public function connect(host:String = "", port:uint = 0):void
		{
			// If the paramters were not passed in, use the host and port properties
			var theHost:String = host == "" ? this.host : host;
			var thePort:uint = port == 0 ? this.port : port;
			
			Security.loadPolicyFile("http://" + theHost + "/crossdomain.xml");
					
			rfb = new RFBProtocol(theHost, thePort);
			rfb.addEventListener(Event.CONNECT , _onConnect);
			rfb.addEventListener(ProgressEvent.SOCKET_DATA , _onSocketData);
			rfb.addEventListener(IOErrorEvent.IO_ERROR, _onIOError);
			rfb.addEventListener(SecurityErrorEvent.SECURITY_ERROR, _onSecurityError);
			rfb.addEventListener(Event.CLOSE, _onClose);
		}
		
		/**
		 * Called when a connection is establisted with the remote server.
		 */
		protected function _onConnect(event:Event):void
		{
			dispatchEvent(event.clone());
		}
		
		/**
		 * Called when there is a problem interacting with data in the socket
		 */
		protected function _onIOError(event:IOErrorEvent):void
		{
			var errorText:String = "";
			
			// Determine what the error message should be based on the connection state
			if (state == ProtocolState.NOT_CONNECTED)
			{
				errorText = "Could not connect to " + host + " on port " + port;
			}
			else
			{
				errorText = event.text;
			}
			
			// Inform listeners of the error condition
			dispatchEvent(new ConnectedVNCErrorEvent(ConnectedVNCErrorEvent.CONNECTION_ERROR, false, true, errorText));
		}
		
		/**
		 * Called when there is a problem interacting with data in the socket
		 */
		protected function _onSecurityError(event:SecurityErrorEvent):void
		{
			var errorText:String = "";
			
			// Determine what the error message should be based on the connection state
			if (state == ProtocolState.NOT_CONNECTED)
			{
				errorText = "Security error prevented connection to " + host + " on port " + port;
			}
			else
			{
				errorText = event.text;
			}
			
			// Inform listeners of the error condition
			dispatchEvent(new ConnectedVNCErrorEvent(ConnectedVNCErrorEvent.CONNECTION_ERROR, false, true, errorText));
		}
		
		/**
		 * Event _onr:  Called whenever new data is available in the
		 * socket.  Based on the state of the protocol, execute the
		 * appropriate function to _on the data coming in.
		 */
		protected function _onSocketData(pe:ProgressEvent):void
		{
	//		trace("[Socket data available: " + rfb.bytesAvailable + "]");
				
			statesMap[ state ](pe);
		}
		
		/**
		 * When the socket initially connects, we need to handshake to
		 * establish version information.
		 */
		protected function handshake(pe:ProgressEvent):void
		{
			rfb.readVersion();
	//		trace("RFB server supports protocol version " + rfb.majorVersion + "." + rfb.minorVersion);
			rfb.writeVersion();
			
			// After version is decided, the protocol is waiting for
			// the authentication scheme
			state = ProtocolState.GET_AUTH_SCHEME;
		}
		
		/**
		 * Called when the protocol responds with the authentication
		 * method available.
		 */
		protected function authenticate(pe:ProgressEvent):void
		{
			var authScheme:int;
			
			try 
			{
				authScheme = rfb.readAuthenticationScheme();
			} 
			catch (ce:ConnectionError)
			{
				close();
				
				// Inform listeners of the connection error when reading authentication
				dispatchEvent(new ConnectedVNCErrorEvent(ConnectedVNCErrorEvent.CONNECTION_ERROR, false, true, ce.message));
				return;
			}
		
			switch (authScheme)
			{
				// Authentication required
				case SecurityType.VNC_AUTHENTICATION:
					
					// After we read the auththentication scheme, we need to get
					// the encryption challenge
					state = ProtocolState.GET_CHALLENGE;			
					
					// Force an onSocketData if the server gave us back
					// all 20 bytes instead of a separate 4 + 16
					if (rfb.bytesAvailable > 0)
					{
						_onSocketData(pe);
					}
					
					break;
				
				// No authentication required
				case SecurityType.NONE:
					state = ProtocolState.READ_SERVER_INIT;
					rfb.writeClientInit(true); // true so display is shared
					break;
			}
			
		}
		
		/**
		 * Saves the encyption challenge sent from the server so that
		 * we can answer the challenge with our password
		 */
		protected function getChallenge(pe:ProgressEvent):void
		{
			challenge = rfb.readChallenge();
			
			// Once we read the challenge, we have to write the 
			// challenege and the next read will be the
			// authentication result
			state = ProtocolState.GET_AUTH_RESULT;
			
			// If we have a password already defined, we can apply it
			// right away.  OTherwise, we dispatch an event letting the
			// user know we're waiting for a password.
			if (_password)
			{
				applyPassword();
				// Clear the password now that we're done with it
				_password = "";
			}
			else
			{
				dispatchEvent(new ConnectedVNCEvent(ConnectedVNCEvent.PASSWORD_REQUIRED));
			}
		}
		
		/**
		 * Helper function to apply the password the user supplied to the
		 * server for authentication.  We use the password as a key to 
		 * encrypt the challenge and then send the encrypted challenege 
		 * back over the wire to complete authentication.
		 */
		private function applyPassword(value:String = null):void
		{
			// Use the stored password if no value is passed in
			vncEncrypt(challenge, value || _password);
			rfb.writeChallenge(challenge);
		}
		
		/**
		 * Encrypt the challenge via a specific password and set challenge to 
		 * be its encrypted value.
		 */
		public static function vncEncrypt(challenge:ByteArray, pw:String):void
		{
			var f:ByteArray = new ByteArray();
			var s:ByteArray = new ByteArray();
			
			f.length = 8;
			s.length = 8;
			
			challenge.position = 0;
			challenge.readBytes(f, 0, 8);
			challenge.readBytes(s, 0, 8);
			
			DES.load();
			
			var des:DES = new DES(pw, true);
			
			challenge.position = 0;
			challenge.writeBytes(des.encrypt(f));
			challenge.writeBytes(des.encrypt(s));
			
			DES.unload();
		}
		
		/**
		 * Called when the authentication result has been received.
		 * Determine if the challenge was accepted and respond
		 * accordinly.
		 */
		private function processAuthResult(pe:ProgressEvent):void
		{
			var authResult:int = rfb.readInt();
			
			switch (authResult)
			{
				case AuthenticationStatus.FAILED:
					// Couldn't conect, so close the socket
					close();
					
					// Let the user know the authentication failed
					dispatchEvent(new ConnectedVNCEvent(ConnectedVNCEvent.INVALID_PASSWORD));
					
					break;
				
				case AuthenticationStatus.OK:
					// We're authorized now, so continue the handshake
					// process by sending the client init and waiting
					// for the server init back
					state = ProtocolState.READ_SERVER_INIT;
					rfb.writeClientInit(true); // true so display is shared
					break;
					
				default:
					var errorText:String = "Unknown authentication result: " + authResult;
					dispatchEvent(new ConnectedVNCErrorEvent(ConnectedVNCErrorEvent.CONNECTION_ERROR, false, true, errorText));
					
					// Couldn't conect, so close the socket
					close();
			}
		}
		
		/** Store the server initialization settings */
		private var serverInit:ServerInit;
		
		/**
		 * Called when the server initialization parameters are
		 * received.
		 */
		private function doInitialization(pe:ProgressEvent):void
		{
			// Wait for enough data in the socket before continuing
			if (rfb.bytesAvailable < 24)
			{
				return;	
			}
			
			serverInit = rfb.readServerInit();
			
			state = ProtocolState.READ_SERVER_NAME;
			// Force an onSocketData if the server gave us back
			// the entire name as part of the init response
			if (rfb.bytesAvailable > 0)
			{
				_onSocketData(pe);
			}
			
		}
		
		/**
		 * 
		 */
		private function doReadServerName(pe:ProgressEvent):void
		{
			// Wait for enough data in the socket before continuing
			if (rfb.bytesAvailable < serverInit.nameLength)
			{
				return;
			}
			
			serverInit.name = rfb.readServerName(serverInit.nameLength);
			
			state = ProtocolState.CONNECTED;
			
			// Now that we're connected, we need to perform some more initialization
			// for the connected state
			initializeConnectedState();
			
			// One we read the server name, we're connect and ready to process
			// the server messages.  If there are any bytes avaialble, then kick
			// start the process (otherwise we just wait for the callback as usual).
			if (rfb.bytesAvailable)
			{
				_onSocketData(pe);
			}
		}
		
		/**
		 * Runs initialization when the socket advances past the handshaking into
		 * the normal connected state.
		 */
		protected function initializeConnectedState():void
		{
			messages = new Array();
			parser = new RFBParser();
			
			// Whenever the player tries to draw a frame, attempt to process a server message
			// to update the screen (chances are the message is a frame buffer update)
			addEventListener(Event.ENTER_FRAME, processServerMessages);
			
			// Create a list of supported encodings, in the order of preference
			var encodings:Array = [ 
									//Encoding.ZLIBHEX
									//,Encoding.ZRLE
									Encoding.HEXTILE
									,Encoding.COPY_RECT
									,Encoding.RRE
									,Encoding.RAW
									,Encoding.CURSOR
								  ];
			
			// Tell the VNC Server our encoding preferences
			rfb.writeSetEncodings(encodings);
			
			// Force a 16-bit pixel format
			// TODO: Let the user configure this
			var pixelFormat:PixelFormat = new PixelFormat();
			pixelFormat.bitsPerPixel = 16;
			pixelFormat.depth = 15;
			pixelFormat.bigEndian = true;
			pixelFormat.trueColor = true;
			pixelFormat.redMax = 31;
			pixelFormat.redShift = 10;
			pixelFormat.greenMax = 31;
			pixelFormat.greenShift = 5;
			pixelFormat.blueMax = 31;
			pixelFormat.blueShift = 0;
			
			// Let the server know the pixel format we're using
			rfb.writeSetPixelFormat(pixelFormat);
			
			// Create the bitmap that we'll perform calculations on
			screenImageData = new BitmapData(serverInit.frameBufferWidth, 
										   	  serverInit.frameBufferHeight, 
										   	  false); // not transparent
										   	  
			// The onScreenPixels are the ones attached to the DisplayList (screen)
			screenImage = new Bitmap(screenImageData);
			screenImage.smoothing = true;
			remoteScreen.addChild(screenImage);
			remoteScreen.width = serverInit.frameBufferWidth;
			remoteScreen.height = serverInit.frameBufferHeight;
			
			// Every time we update the frame buffer, we'll ask to update the frame buffer
			// again, which means we need to send the bounds rectangle.  So, we'll save
			// the screen bounds as a rectangle for re-use in asking for the updates.
			screenBounds = new Rectangle(0, 0, 
									serverInit.frameBufferWidth,
									serverInit.frameBufferHeight);
			
			// Request the initial screen from the server
			rfb.writeFrameBufferUpdateRequest(screenBounds, false);
			
			/*
			// Whenever the mouse moves, let the server know
			remoteScreen.addEventListener(MouseEvent.MOUSE_MOVE, _onMouseEvent);
			remoteScreen.addEventListener(MouseEvent.MOUSE_DOWN, _onMouseEvent);
			remoteScreen.addEventListener(MouseEvent.MOUSE_UP, _onMouseEvent);
			remoteScreen.addEventListener(MouseEvent.MOUSE_WHEEL, _onMouseEvent);
			
			// Whenever a key is pressed, let the server know
			addEventListener(KeyboardEvent.KEY_UP, _onKeyUp);
			addEventListener(KeyboardEvent.KEY_DOWN, _onKeyDown);
			*/
			
			enableFitToScreen(fitToScreen);
			
			ExternalInterface.addCallback("onKeyEvent", _onKeyEvent);
		}
		
		/**
		 * Map remote control buttons to keys and mouse movement
		 */
		protected function _onKeyEvent(id:uint) : void
		{
			// Buttons mapped to keys
			
			switch(id)
			{
				case 36:
					_sendKeyboardEvent(new KeyboardEvent("", false, false, 0, Keyboard.BACKSPACE));
					return;
				
				case 22:
					_sendKeyboardEvent(new KeyboardEvent("", false, false, 48, Keyboard.NUMPAD_0));
					return;
					
				case 23:
					_sendKeyboardEvent(new KeyboardEvent("", false, false, 49, Keyboard.NUMPAD_1));
					return;
				
				case 24:
					_sendKeyboardEvent(new KeyboardEvent("", false, false, 50, Keyboard.NUMPAD_2));
					return;

				case 25:
					_sendKeyboardEvent(new KeyboardEvent("", false, false, 51, Keyboard.NUMPAD_3));
					return;

				case 26:

					_sendKeyboardEvent(new KeyboardEvent("", false, false, 52, Keyboard.NUMPAD_4));
					return;

				case 27:
					_sendKeyboardEvent(new KeyboardEvent("", false, false, 53, Keyboard.NUMPAD_5));
					return;

				case 28:
					_sendKeyboardEvent(new KeyboardEvent("", false, false, 54, Keyboard.NUMPAD_6));
					return;

				case 29:
					_sendKeyboardEvent(new KeyboardEvent("", false, false, 55, Keyboard.NUMPAD_7));
					return;

				case 30:
					_sendKeyboardEvent(new KeyboardEvent("", false, false, 56, Keyboard.NUMPAD_8));
					return;

				case 31:
					_sendKeyboardEvent(new KeyboardEvent("", false, false, 57, Keyboard.NUMPAD_9));
					return;

				default:
					break;
			}
			
			// Buttons mapped to mouse movement
			
			var time:int = getTimer();
			var distance:int = time-_mouseTime < 90 ? 80 : 10;
			
			switch(id)
			{
				// Up, down, left, right
				case 1:
					_mouseCursor.y = _mouseCursor.y - distance;
					_sendMouseEvent();
					if (_mouseDown) return;
					break;
				case 2:
					_mouseCursor.y = _mouseCursor.y + distance;
					_sendMouseEvent();
					if (_mouseDown) return;
					break;
				case 3:
					_mouseCursor.x = _mouseCursor.x - distance;
					_sendMouseEvent();
					if (_mouseDown) return;
					break;
				case 4:
					_mouseCursor.x = _mouseCursor.x + distance;
					_sendMouseEvent();
					if (_mouseDown) return;
					break;
					
				// Select (left click)
				case 6:
					_sendMouseEvent(true);
					break;
				
				// Menu (right click)
				case 15:
					_sendMouseEvent(false, 0, true);
					break;

				// Dot (toggle drag)
				case 35:
					_mouseDown = !_mouseDown;
					_sendMouseEvent(_mouseDown);
					return;
					
				// Page up, page down
				case 16:
					_sendMouseEvent(false, 1);
					break;
				case 17:
					_sendMouseEvent(false, -1);
					break;
					
				default:
					return;
			}
			
			_mouseDown = false;
			_mouseTime = time;
			
			callLater(_sendMouseEvent);
		}
		
		protected function _sendKeyboardEvent(event:KeyboardEvent) : void
		{
			rfb.writeKeyDownEvent(event);
			rfb.writeKeyUpEvent(event);
			return;
		}

		protected function _sendMouseEvent(buttonDown:Boolean=false, delta:int=0, rightButtonDown:Boolean=false):void
		{
			if (_mouseCursor.x >= remoteScreen.x+remoteScreen.width) _mouseCursor.x = remoteScreen.x+remoteScreen.width-1; 
			if (_mouseCursor.x < remoteScreen.x) _mouseCursor.x = remoteScreen.x; 
			if (_mouseCursor.y >= remoteScreen.y+remoteScreen.height) _mouseCursor.y = remoteScreen.y+remoteScreen.height-1; 
			if (_mouseCursor.y < remoteScreen.y) _mouseCursor.y = remoteScreen.y;
			
			buttonDown = _mouseDown || buttonDown;
			
			_mouseCursor.alpha = _mouseDown ? 0.4 : 1;			
			
			var mousePoint:Point = new Point(Math.round(_mouseCursor.x), Math.round(_mouseCursor.y));
			mousePoint = localToGlobal(mousePoint);
			mousePoint = remoteScreen.globalToLocal(mousePoint);
			
			var event:MouseEvent = new MouseEvent(MouseEvent.MOUSE_MOVE, false, false, mousePoint.x, mousePoint.y, remoteScreen, false, false, false, buttonDown, delta);
			rfb.writePointerEvent(event, rightButtonDown);
		}		
		
		/**
		 * 
		 */
		private function parseServerMessages(pe:ProgressEvent):void
		{
			// Parse the new data the came in
			var newMessages:Array = parser.parse(rfb);
					
			// Merge any existing messages with the new ones that were just read
			if (newMessages.length)
			{
				messages = messages.concat(newMessages);
			}
		}
		
		/**
		 * Event _onr:  Called whenever the player tries to draw a frame.  This
		 * will inspect the parsed messages and act on them (which is most likely 
		 * a frame buffer update that causes changes to the screen)
		 */
		private function processServerMessages(event:Event):void
		{
			// Only process if there is at least one complete message available
			if (messages.length)
			{
				for (var i:int = 0; i < messages.length; i++)
				{
					var message:RFBServerMessage = messages[i];
					message.execute(screenImageData);
				}
	
				// Clear the messages that have been executed
				messages = new Array();
				
				// TODO: Where to put the below code?  If we put it in this loop
				// the remote screen doesn't appear as responsive, but if we
				// put it outsite the loop, that's a lot of network traffic
				// and procudes intermittent errors when reading the RFB data...
			
				// Ask for the latest screen from the server
				rfb.writeFrameBufferUpdateRequest(screenBounds);
			}
			
		}
		
		/**
		 * Event _onr:  Called when we receive a key release.  Send the event
		 * over RFB to the remote server.
		 */
		private function _onKeyUp(event:KeyboardEvent):void
		{
			// Prevent the key event from bubbling up the UI.  This is importnt
			// as, for example, if we press the "up" arrow key the remoteScreen
			// might think we're pressing "up" to move the scrollbars up if 
			// they are displayed.  We don't want this side effect, so stopping
			// the event at this level prevents anyone else from handling it.
			event.stopPropagation();
			rfb.writeKeyUpEvent(event);
		}
		
		/**
		 * Event _onr:  Called when we receive a key release.  Send the event
		 * over RFB to the remote server.
		 */
		private function _onKeyDown(event:KeyboardEvent):void
		{
			Alert.show(event.toString(), "Key Press");
			
			// Prevent the key event from bubbling up the UI.  This is importnt
			// as, for example, if we press the "up" arrow key the remoteScreen
			// might think we're pressing "up" to move the scrollbars up if 
			// they are displayed.  We don't want this side effect, so stopping
			// the event at this level prevents anyone else from handling it.
			event.stopPropagation();
			rfb.writeKeyDownEvent(event);
		}
		
		/**
		 * Event hadler; invoked when the remote server terminiates the connection.
		 */
		protected function _onClose(event:Event):void
		{
			close();
		}
		
		/**
		 * Closes the socket connection (disconnects from the remote server).
		 */
		public function close():void
		{
			if (state != ProtocolState.NOT_CONNECTED)
			{
				/*
				// Remove event listeners that might've been assigned if we were
				// previously in the connected state
				remoteScreen.removeEventListener(MouseEvent.MOUSE_MOVE, _onMouseEvent);
				remoteScreen.removeEventListener(MouseEvent.MOUSE_DOWN, _onMouseEvent);
				remoteScreen.removeEventListener(MouseEvent.MOUSE_UP, _onMouseEvent);
				remoteScreen.removeEventListener(MouseEvent.MOUSE_WHEEL, _onMouseEvent);
				*/
				
				rfb.removeEventListener(Event.CONNECT , _onConnect);
				rfb.removeEventListener(ProgressEvent.SOCKET_DATA , _onSocketData);
				rfb.removeEventListener(IOErrorEvent.IO_ERROR, _onIOError);
				rfb.removeEventListener(Event.CLOSE, _onClose);
				
				removeEventListener(KeyboardEvent.KEY_UP, _onKeyUp);
				removeEventListener(KeyboardEvent.KEY_DOWN, _onKeyDown);
				removeEventListener(Event.ENTER_FRAME, processServerMessages);
				
				// Clear the socket
				state = ProtocolState.NOT_CONNECTED;
				rfb.close();
				rfb = null;
				parser = null;
				
				dispatchEvent(new Event(Event.CLOSE));
			}
		}
		
		// TODO: This is probably better off in a "scaleContent" property
		/**
		 * Change the scale based on whether or not the whole remote screen should
		 * be fit into the current display area.
		 */
		public function enableFitToScreen(enable:Boolean = true):void
		{
			if (enable)
			{
				// Fit to screen
				var metrics:EdgeMetrics = viewMetrics;
				remoteScreen.scaleX = (width - viewMetrics.left - viewMetrics.right) / remoteScreen.width;
				remoteScreen.scaleY = (height - viewMetrics.top - viewMetrics.bottom) / remoteScreen.height;
				verticalScrollPolicy = "off";
				horizontalScrollPolicy = "off";
				
				// Maintain aspect ratio
				remoteScreen.scaleX = Math.min(remoteScreen.scaleX, remoteScreen.scaleY);
				remoteScreen.scaleY = remoteScreen.scaleX;
				
				// Centre
				remoteScreen.validateNow();
				remoteScreen.x = (width-remoteScreen.width)/2;
				
				_mouseCursor.x = width/2;
				_mouseCursor.y = height/2;
				
				addChild(_mouseCursor);
			}
			else
			{
				remoteScreen.scaleX = 1;
				remoteScreen.scaleY = 1;
				verticalScrollPolicy = "auto";
				horizontalScrollPolicy = "auto";	
			}
		}
		
	} // end class
} // end package