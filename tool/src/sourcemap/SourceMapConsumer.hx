package sourcemap;

import SourceMap;

typedef EachMapping = {
	source:String,
	generatedLine:Int,
	generatedColumn:Int,
	originalLine:Int,
	originalColumn:Int,
	name:String
}

@:jsRequire('source-map', 'SourceMapConsumer')
extern class SourceMapConsumer
{
	static public var GENERATED_ORDER:String;
	static public var ORIGINAL_ORDER:String;
	
	public function new(rawSourceMap:SourceMapFile);
	
	/**
	 * Iterate over each mapping between an original source/line/column and a generated 
	 * line/column in this source map.
	 */
	public function eachMapping(callback:EachMapping->Void, ?context:Dynamic, ?order:String):Void;
	
	/**
	 * Returns the original source content for the source provided. The only argument is the URL of the original source file.
	 */
	public function sourceContentFor(source:String, ?returnNullIfMissing:Bool):String;
}
