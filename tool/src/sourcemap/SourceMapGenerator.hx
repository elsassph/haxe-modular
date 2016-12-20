package sourcemap;

typedef SourceMapStart = {
	file:String,
	sourceRoot:String,
	skipValidation:Bool
}

typedef Location = {
	line:Int,
	column:Int
}

typedef DefMapping = {
	source:String,
	original:Location,
	generated:Location
}

@:jsRequire('source-map', 'SourceMapGenerator')
extern class SourceMapGenerator
{
	public var file:String; 
	public var sourceRoot:String;
	
	public function new(?startOfSourceMap:SourceMapStart);
	
	/**
	 * Add a single mapping from original source line and column to the generated source's 
	 * line and column for this source map being created. 
	 */
	public function addMapping(mapping:DefMapping):Void;
	
	/**
	 * Set the source content for an original source file.
	 */
	public function setSourceContent(sourceFile:String, sourceContent:String):Void;

	/**
	 * Applies a SourceMap for a source file to the SourceMap. Each mapping to the supplied 
	 * source file is rewritten using the supplied SourceMap. Note: The resolution for the 
	 * resulting mappings is the minimum of this map and the supplied map.
	 */
	public function applySourceMap(sourceMapConsumer:SourceMapConsumer, ?sourceFile:String, ?sourceMapPath:String):Void;

	/**
	 * Renders the source map being generated to a string.
	 */
	public function toString():String;
	
	/**
	 * Creates a new SourceMapGenerator from an existing SourceMapConsumer instance.
	 */
	static function fromSourceMap(sourceMapConsumer:SourceMapConsumer):SourceMapGenerator;
}
