package com.mesmotronic.mx.preloaders
{
	import flash.display.CapsStyle;
	import flash.display.DisplayObject;
	import flash.display.LineScaleMode;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.geom.Point;
	import flash.system.Capabilities;
	
	import mx.events.FlexEvent;
	import mx.preloaders.DownloadProgressBar;
	
	/**
	 * Simple Preloader (Black)
	 * @author Mesmotronic
	 */
	public class SimplePreloaderBlack extends DownloadProgressBar
	{
		protected var _centre:Sprite;
		protected var _logo:Class;
		
		public function SimplePreloaderBlack() 
		{
			graphics.beginFill(0x000000);
			graphics.drawRect(0, 0, Capabilities.screenResolutionX*2, Capabilities.screenResolutionY*2);
			graphics.endFill();
			
			addEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
		}
		
		protected function _onAddedToStage(event:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
			stage.addEventListener(Event.RESIZE, _onResize);
			
			_centre = new Sprite;
			_centre.graphics.lineStyle(1, 0xFFFFFF);
			_centre.graphics.drawRect(_centre.x-100, _centre.y-3, 200, 6)
			
			addChild(_centre);
			
			_onResize();
		}
		
        override public function set preloader(target:Sprite):void
        {                   
            target.addEventListener(ProgressEvent.PROGRESS, _onProgress);    
            target.addEventListener(Event.COMPLETE, _onComplete);
            target.addEventListener(FlexEvent.INIT_PROGRESS, _onInitProgress);
            target.addEventListener(FlexEvent.INIT_COMPLETE, _onInitComplete);
        }
		
		protected function _onResize(event:Event=null):void
		{
			_centre.x = stage.stageWidth/2;
			_centre.y = stage.stageHeight/2;
		}
		
        protected function _onProgress(event:ProgressEvent):void
		{
			var w:Number = event.bytesLoaded/event.bytesTotal * 200;
			
			_centre.graphics.lineStyle(6, 0xFFFFFF, 1, false, LineScaleMode.NONE, CapsStyle.NONE);
			_centre.graphics.moveTo(-100, 0);
			_centre.graphics.lineTo(-100+w, 0);
		}
		
        protected function _onComplete(event:Event):void
		{
		}
    
        protected function _onInitProgress(event:FlexEvent):void
		{
		}
    
        protected function _onInitComplete(event:FlexEvent):void
        {
        	stage.removeEventListener(Event.RESIZE, _onResize);
			dispatchEvent(new Event(Event.COMPLETE));
        }
	}
}
