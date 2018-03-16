package;

import haxe.Json;
import js.node.Fs;
import graphlib.Graph;

class HxSplit
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
		if (debugSourceMap) dumpGraph(output, parser.graph);
		var extractor = new Extractor(parser);
		extractor.process(parser.mainModule, modules, debugMode);

		// emit
		var reporter = new Reporter(dump);
		var bundler = new Bundler(parser, sourceMap, extractor, reporter);
		var result = bundler.generate(src, output, commonjs, debugSourceMap);

		if (debugSourceMap) dumpModules(output, extractor);
		if (dump) reporter.save(output);
		return result;
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

	static function dumpModules(output:String, extractor:Extractor)
	{
		trace('Dump bundles: ${output}.json');
		var bundles = [extractor.main].concat(extractor.bundles);
		for (bundle in bundles) {
			Reflect.deleteField(bundle, 'indexes');
			bundle.nodes.sort(null);
		}

		var out = Json.stringify(bundles, '  ');
		Fs.writeFileSync(output + '.json', out);
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
