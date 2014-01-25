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
	import flash.events.ErrorEvent;

	/**
	 * 
	 */
	public class ConnectedVNCErrorEvent extends ErrorEvent
	{
		/** Static conast for the connection error event type. */
		public static const CONNECTION_ERROR:String = "connectionError";
		
		/**
		 * Constructor
		 */
		public function ConnectedVNCErrorEvent( type:String, bubble:Boolean = false, cancelable:Boolean = true, text:String = "" )
		{
			super( type, bubbles, cancelable, text );
		}
	}
}