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
	
	public function emitMappings(nodes:Array<AstNode>, offset:Int):SourceMapGenerator
	{
		if (nodes.length == 0 || source == null) return null;
		
		var inc:Array<Null<Int>> = [];
		var line = 3 + offset;
		//untyped console.log(nodes[0].expression);
		for (node in nodes)
		{
			for (i in node.loc.start.line...node.loc.end.line + 1)
				inc[i] = line++;
		}
		
		var output = new SourceMapGenerator();
		source.eachMapping(function(mapping:EachMapping) {
			if (!Math.isNaN(inc[mapping.generatedLine]))
			{
				var mapLine = inc[mapping.generatedLine];
				output.addMapping({
					source:mapping.source,
					original:{ line:mapping.originalLine, column:mapping.originalColumn },
					generated:{ line:mapLine, column:mapping.generatedColumn }
				});
			}
		});
		return output;
	}
	
	public function emitFile(output:String, map:SourceMapGenerator) 
	{
		if (map == null) return null;
		
		map.file = Path.basename(output);
		return map.toString();
	}
}