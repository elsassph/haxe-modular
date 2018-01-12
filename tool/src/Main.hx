package;

import js.node.Fs;
import js.node.Path;
import graphlib.Graph;

class Main
{
	@:expose('run')
	static function run(input:String, output:String, modules:Array<String>,
		debugMode:Bool, commonjs:Bool, debugSourceMap:Bool, dump:Bool,
		astHooks:Array<Graph->String->Array<String>>)
	{
		// parse input
		var src = Fs.readFileSync(input).toString();
		var parser = new Parser(src, debugMode);
		var sourceMap = debugMode ? new SourceMap(input, src) : null;

		// external hook
		modules = applyAstHooks(parser.mainModule, modules, astHooks, parser.graph);

		// process
		if (dump) dumpGraph(output, parser.graph);
		var extractor = new Extractor(parser);
		extractor.process(parser.mainModule, modules, debugMode);

		// emit
		var bundler = new Bundler(parser, sourceMap, extractor);
		return bundler.generate(src, output, commonjs, debugSourceMap);
	}

	static function applyAstHooks(mainModule:String, modules:Array<String>,
		astHooks:Array<Graph->String->Array<String>>, graph:Graph)
	{
		if (astHooks == null || astHooks.length == 0) return modules;
		for (hook in astHooks) {
			if (hook == null) continue;
			var addModules = hook(graph, mainModule);
			if (addModules != null) modules = modules.concat(addModules);
		}
		return modules;
	}

	static function dumpGraph(output:String, g:Graph)
	{
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
