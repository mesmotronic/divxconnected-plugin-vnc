package com.mesmotronic.media
{
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.net.URLRequest;
	
	[Event(name="complete",type="flash.events.Event")]
	[Event(name="open",type="flash.events.Event")]
	[Event(name="soundComplete",type="flash.events.Event")]
	[Event(name="ioError",type="flash.events.IOErrorEvent")]
	[Event(name="error",type="flash.events.ErrorEvent")]
	[Event(name="progress",type="flash.events.ProgressEvent")]
	[Event(name="id3",type="flash.events.ProgressEvent")]
	
	[Bindable]
	public class StreamingAudio extends EventDispatcher
	{
		public var autoPlay:Boolean = true;
		
		protected var _source:String;
		protected var _sound:Sound;
		protected var _channel:SoundChannel;
		
		public function StreamingAudio()
		{
			//
		}
		
		public function get source():String
		{
			return _source;
		}
		public function set source(value:String):void
		{
			_source = value;
			if (autoPlay) play();
		}
		
		public function play():void
		{
			stop();
			
			if (_sound)
			{
				_sound.removeEventListener(IOErrorEvent.IO_ERROR, _onEvent);
				_sound.removeEventListener(Event.OPEN, _onEvent);
				_sound.removeEventListener(Event.COMPLETE, _onEvent);
				_sound.removeEventListener(ProgressEvent.PROGRESS, _onEvent);
				_sound.removeEventListener(Event.ID3, _onEvent);
			}
			
			_sound = new Sound;
			_sound.addEventListener(IOErrorEvent.IO_ERROR, _onEvent);
			_sound.addEventListener(Event.OPEN, _onEvent);
			_sound.addEventListener(Event.COMPLETE, _onEvent);
			_sound.addEventListener(ProgressEvent.PROGRESS, _onEvent);
			_sound.addEventListener(Event.ID3, _onEvent);
			_sound.load(new URLRequest(_source)); //, new SoundLoaderContext(10000, true));
			
			try
			{
				_channel = _sound.play();
				_channel.addEventListener(Event.SOUND_COMPLETE, _onEvent);
			}
			catch (e:Error)
			{
				// dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, "Sound channel could not be created"));
			}
		}
		
		public function stop():void
		{
			try { _sound.close(); }
			catch (e:Error) {}
			
			if (_channel) _channel.stop();
		}
		
		protected function _onEvent(event:Event):void
		{
			if (event is IOErrorEvent && !hasEventListener(IOErrorEvent.IO_ERROR)) return;
			dispatchEvent(event.clone());
		}
	}
}