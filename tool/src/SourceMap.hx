package;

import acorn.Acorn.AstNode;
import haxe.Json;
import js.node.Fs;
import js.node.Path;
import sourcemap.SourceMapConsumer;
import sourcemap.SourceMapGenerator;
import sourcemap.SourceMapGenerator.DefMapping;

typedef SourceMapFile = {
	version:Int,
	file:String,
	sourceRoot:String,
	sources:Array<String>,
	sourcesContent:Array<String>,
	names:Array<String>,
	mappings:String
}

class SourceMap
{
	static public inline var SRC_REF = '//# sourceMappingURL=';

	var fileName:String;
	var source:SourceMapConsumer;
	var lines:Array<String>;

	public function new(input:String, src:String)
	{
		var p = src.lastIndexOf(SRC_REF);
		if (p < 0) return;
		fileName = StringTools.trim(src.substr(p + SRC_REF.length));
		fileName = Path.join(Path.dirname(input), fileName);
		var raw:SourceMapFile = Json.parse(Fs.readFileSync(fileName).toString());
		source = new SourceMapConsumer(raw);
	}

	/**
	 * Copy mappings from original sourcemap for the included code
	 */
	public function emitMappings(nodes:Array<AstNode>, offset:Int):SourceMapGenerator
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
		var output = new SourceMapGenerator();
		var sourceFiles = {};
		try {
			// filter mappings by flagged lines
			source.eachMapping(function(mapping:EachMapping) {
				if (!Math.isNaN(inc[mapping.generatedLine]))
				{
					Reflect.setField(sourceFiles, mapping.source, true);

					var mapLine = inc[mapping.generatedLine];
					var column = mapping.originalColumn >= 0 ? mapping.originalColumn : 0;
					output.addMapping({
						source:mapping.source,
						original:{ line:mapping.originalLine, column:column },
						generated:{ line:mapLine, column:mapping.generatedColumn }
					});
				}
			});

			// copy sourceContent if present
			for (sourceName in Reflect.fields(sourceFiles))
			{
				var src = source.sourceContentFor(sourceName, true);
				if (src != null) output.setSourceContent(sourceName, src);
			}

			return output;
		}
		catch (err:Dynamic) {
			trace('Invalid source-map');
		}
		return output;
	}

	/**
	 * Set sourcemap's filename and serialize
	 */
	public function emitFile(output:String, map:SourceMapGenerator):SourceMapGenerator
	{
		if (map == null) return null;

		map.file = Path.basename(output);
		return map;
	}
}