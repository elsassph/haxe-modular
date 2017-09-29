package;

import js.node.Fs;
import js.node.Path;

class Main
{
	@:expose('run')
	static function run(input:String, output:String, modules:Array<String>, debugMode:Bool, webpackMode:Bool, dump:Bool)
	{
		// parse input
		var src = Fs.readFileSync(input).toString();
		var parser = new Parser(src);
		var sourceMap = new SourceMap(input, src);
		if (dump) dumpGraph(output, parser);

		// process
		var extractor = new Extractor(parser);
		extractor.process(parser.mainModule, modules, debugMode);

		// emit
		var bundler = new Bundler(parser, sourceMap, extractor);
		var dir = Path.dirname(output);
		if (!Fs.statSync(dir).isDirectory()) Fs.mkdirSync(dir);
		return bundler.generate(src, output, webpackMode);
	}

	static function dumpGraph(output:String, parser:Parser)
	{
		var g = parser.graph;
		trace('Dump graph: ${output}.graph');
		var out = '';
		for (node in g.nodes()) {
			if (node.charAt(0) != '$') {
				var toNode = g.inEdges(node)
					.map(function(n) return n.v.split('_').join('.'))
					.filter(function(l) return l.charAt(0) != '$');
				if (toNode.length == 0)
					continue;
				out += '+ ${node} < ${toNode.join(', ')}\n';
				var fromNode = g.outEdges(node)
					.map(function(n) return n.w.split('_').join('.'))
					.filter(function(l) return l.charAt(0) != '$');
				for (dest in fromNode) {
					out += '  - $dest\n';
				}
			}
		}
		Fs.writeFileSync(output + '.graph', out);
	}
}
