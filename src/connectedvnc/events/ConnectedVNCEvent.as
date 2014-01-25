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

package connectedvnc.events
{
	
	import flash.events.Event;
	
	/**
	 * A common base class for events broadcast by the FVNC component.
	 */
	public class ConnectedVNCEvent extends Event 
	{
		/** Static constant for the invalid password event type. */
		public static const INVALID_PASSWORD:String = "invalidPassword";
		
		/** Static constant for the password required event type. */
		public static const PASSWORD_REQUIRED:String = "passwordRequired";
	
		/**
		 * Constructor
		 * 
		 * @type One of the FVNCEvent public static constants.
		 */
		public function ConnectedVNCEvent( type:String, bubbles:Boolean = false, cancelable:Boolean = false )
		{
			super( type, bubbles, cancelable );
		}
		
		/**
		 * Override clone to support re-dispatching
		 */
		override public function clone():Event
		{
			return new ConnectedVNCEvent( type, bubbles, cancelable );
		}
	
	}
}