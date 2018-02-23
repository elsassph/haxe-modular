package;

import acorn.Acorn.AstNode;
import js.node.Path;

typedef SourceMapFile = {
	version:Int,
	file:String,
	sourceRoot:String,
	sources:Array<String>,
	sourcesContent:Array<String>,
	names:Array<String>,
	mappings:String
}

typedef Mapping = {
	col: Int,
	name: Int,
	src: Int,
	srcCol: Int,
	srcLine: Int,
}

typedef LineMapping = Array<Mapping>;

typedef DecodedSourceMapFile = {
	version:Int,
	file:String,
	sourceRoot:String,
	sources:Array<String>,
	sourcesContent:Array<String>,
	names:Array<String>,
	mappings:Array<LineMapping>
}

@:jsRequire('@elsassph/fast-source-map')
extern class SM {
	public static function decode(map:SourceMapFile):DecodedSourceMapFile;
	public static function decodeFile(path:String):DecodedSourceMapFile;
	public static function encode(map:DecodedSourceMapFile):SourceMapFile;
	public static function encodeFile(path:String):SourceMapFile;
}

class SourceMap
{
	static public inline var SRC_REF = '//# sourceMappingURL=';

	var fileName:String;
	var source:DecodedSourceMapFile;
	var lines:Array<String>;

	public function new(input:String, src:String)
	{
		var p = src.lastIndexOf(SRC_REF);
		if (p < 0) return;
		fileName = StringTools.trim(src.substr(p + SRC_REF.length));
		fileName = Path.join(Path.dirname(input), fileName);
		source = SM.decodeFile(fileName);
	}

	/**
	 * Copy mappings from original sourcemap for the included code
	 */
	public function emitMappings(nodes:Array<AstNode>, offset:Int):SourceMapFile
	{
		if (nodes.length == 0 || source == null) return null;

		// flag lines from original source that we want to include
		var inc:Array<Null<Int>> = [];
		var line = offset;
		for (node in nodes)
		{
			for (i in node.loc.start.line...node.loc.end.line + 1)
				inc[i] = line++;
		}

		// new sourcemap
		var output:Array<LineMapping> = [];
		var map:DecodedSourceMapFile = {
			version: 3,
			file: '',
			sourceRoot: '',
			sources: [],
			sourcesContent: [],
			names: [],
			mappings: null
		};
		var usedSources:Array<Bool> = [];
		try {
			// filter mappings by flagged lines
			var mappings = source.mappings;
			var srcLength = mappings.length;
			var maxLine = 0;
			for (i in 0...srcLength) {
				var mapping:LineMapping = mappings[i];
				if (!Math.isNaN(inc[i]))
				{
					for (m in mapping) usedSources[m.src] = true;
					var mapLine = inc[i];
					output[mapLine] = mapping;
					maxLine = mapLine > maxLine ? mapLine : maxLine;
				}
			}
			// fill the holes (it works without, but what will be faster?)
			for (i in 0...maxLine) {
				if (output[i] == null) output[i] = [];
			}

			// set used sources
			for (i in 0...source.sources.length)
				map.sources[i] = usedSources[i] ? formatPath(source.sources[i]) : null;
			map.mappings = output;

			// encode mappings
			return SM.encode(map);
		}
		catch (err:Dynamic) {
			trace('Invalid source-map');
			return null;
		}
	}

	function formatPath(path:String)
	{
		return path.indexOf('file://') < 0 ? 'file://' + path : path;
	}

	/**
	 * Set sourcemap's filename and serialize
	 */
	public function emitFile(output:String, map:SourceMapFile):SourceMapFile
	{
		if (map == null) return null;

		map.file = Path.basename(output);
		return map;
	}
}