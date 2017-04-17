import acorn.Acorn.AstNode;
import graphlib.Graph;
import js.node.Fs;
import js.node.Path;
import sourcemap.SourceMapGenerator;

typedef Bundle = {
	name:String,
	nodes:Array<String>,
	shared:Array<String>
}

typedef OutputBuffer = {
	src:String,
	map:SourceMapGenerator
}

class Bundler
{
	static inline var REQUIRE = "var require = (function(r){ return function require(m) { return r[m]; } })($hx_exports.__registry__);\n";
	static inline var SHARED = "var $s = $hx_exports.__shared__ = $hx_exports.__shared__ || {};\n";
	static inline var SCOPE = "typeof $hx_scope != \"undefined\" ? $hx_scope : $hx_scope = {}";
	static inline var GLOBAL = "typeof window != \"undefined\" ? window : typeof global != \"undefined\" ? global : typeof self != \"undefined\" ? self : this";
	static inline var ARGS = '})($SCOPE, $GLOBAL);\n';
	static inline var FUNCTION = "function ($hx_exports, $global)";

	var parser:Parser;
	var sourceMap:SourceMap;
	var main:Bundle;
	var mainExports:Array<String>;
	var bundles:Array<Bundle> = [];

	public function new(parser:Parser, sourceMap:SourceMap)
	{
		this.parser = parser;
		this.sourceMap = sourceMap;
	}

	public function generate(src:String, output:String)
	{
		trace('Emit $output');
		var buffer = emitBundle(src, main, mainExports, true);
		writeMap(output, buffer);
		write(output, buffer.src);

		for (bundle in bundles)
		{
			var bundleOutput = Path.join(Path.dirname(output), bundle.name + '.js');
			trace('Emit $bundleOutput');
			buffer = emitBundle(src, bundle, [bundle.name], false);
			writeMap(bundleOutput, buffer);
			write(bundleOutput, buffer.src);
		}
	}

	function writeMap(output:String, buffer:OutputBuffer)
	{
		if (buffer.map == null) return;
		write('$output.map', sourceMap.emitFile(output, buffer.map));
		buffer.src += '\n' + SourceMap.SRC_REF + Path.basename(output) + '.map';
	}

	function write(output:String, buffer:String)
	{
		if (buffer == null) return;
		if (hasChanged(output, buffer))
			Fs.writeFileSync(output, buffer);
	}

	function hasChanged(output:String, buffer:String)
	{
		if (!Fs.existsSync(output)) return true;
		var original = Fs.readFileSync(output).toString();
		return original != buffer;
	}

	function emitBundle(src:String, bundle:Bundle, exports:Array<String>, isMain:Bool):OutputBuffer
	{
		var buffer = '';
		var body = parser.rootBody.copy();
		var head = body.shift();
		var run = isMain ? body.pop() : null;
		var inc = bundle.nodes;
		var mapNodes:Array<AstNode> = [];
		var mapOffset = 0;

		// header
		buffer += verifyExport(src.substr(0, head.end + 1));

		// shared scope
		buffer += REQUIRE;
		mapOffset++;
		buffer += SHARED;
		mapOffset++;
		if (bundle.shared.length > 0)
		{
			var tmp = isMain
				? bundle.shared
				: [for (node in bundle.shared) '$node = $$s.$node'];
			buffer += 'var ${tmp.join(', ')};\n';
			mapOffset++;
		}

		// split main content
		for (node in body)
		{
			if (node.__tag__ != null && inc.indexOf(node.__tag__) < 0)
				continue;
			mapNodes.push(node);
			buffer += src.substr(node.start, node.end - node.start);
			buffer += '\n';
		}

		// hot-reload
		buffer += emitHot(inc);

		// reference shared types
		if (exports.length > 0)
		{
			for (node in exports)
				buffer += '$$s.$node = $node; ';
			buffer += '\n';
		}

		// entry point
		if (run != null)
		{
			buffer += src.substr(run.start, run.end - run.start);
			buffer += '\n';
		}

		buffer += ARGS;
		return {
			src:buffer,
			map:sourceMap.emitMappings(mapNodes, mapOffset)
		}
	}

	function emitHot(inc:Array<String>)
	{
		var names = [];
		for (name in parser.isHot.keys())
			if (inc.indexOf(name) >= 0) names.push(name);

		if (names.length == 0) return '';

		return 'if ($$global.__REACT_HOT_LOADER__)\n'
			+ '  [${names.join(",")}].map(function(name) {\n'
			+ '    __REACT_HOT_LOADER__.register(name,name.displayName,name.__fileName__);\n'
			+ '  });\n';
	}

	function verifyExport(s:String)
	{
		return ~/function \([^)]*\)/.replace(s, FUNCTION);
	}

	public function process(modules:Array<String>, debugMode:Bool)
	{
		trace('Bundling...');
		var g = parser.graph;

		// create separated sub-trees for main and modules bundles
		for (module in modules)
			unlink(g, module);

		// find main nodes
		var mainNodes = Alg.preorder(g, 'Main');

		// /!\ force hoist enums in main bundle to avoid HMR conflicts
		if (debugMode)
			for (key in parser.isEnum.keys()) mainNodes.push(key);

		// find modules nodes
		bundles = [
			for (module in modules) {
				name: module,
				nodes: Alg.preorder(g, module),
				shared: []
			}
		];

		// hoist common nodes into main bundle
		var dupes = deduplicate(bundles, mainNodes, debugMode);
		mainNodes = addOnce(mainNodes, dupes.removed);
		mainExports = dupes.shared;

		main = {
			name: 'Main',
			nodes: mainNodes,
			shared: modules
		}
	}

	function deduplicate(bundles:Array<Bundle>, mainNodes:Array<String>, debugMode:Bool)
	{
		trace('Extract common chunks...' + (debugMode ? ' (fast)' : ''));

		// map the nodes referenced in several bundles
		// /!\ in debug mode, only deduplicate nodes in the main bundle to allow HMR of shared components
		var map = new Map<String, Bool>();
		for (node in mainNodes) map.set(node, true);
		var dupes = [];
		for (bundle in bundles)
		{
			for (node in bundle.nodes)
				if (map.exists(node)) {
					if (dupes.indexOf(node) < 0) dupes.push(node);
				}
				else if (!debugMode) map.set(node, true);
		}

		// find dependencies to share
		var shared = [];
		var g = parser.graph;
		for (node in dupes)
		{
			// a node should be shared if not a transitive dependency of a shared node
			var pre = g.predecessors(node)
				.filter(function(preNode) return dupes.indexOf(preNode) < 0);
			if (pre.length > 0) shared.push(node);
		}

		// remove common nodes from bundles and mark them as shared
		for (bundle in bundles)
		{
			bundle.nodes = bundle.nodes.filter(function(node) {
				if (dupes.indexOf(node) < 0) return true;
				if (shared.indexOf(node) >= 0) bundle.shared.push(node);
				return false;
			});
		}

		trace('Moved ${dupes.length} common chunks (${shared.length} shared)');
		return {
			removed:dupes,
			shared:shared
		}
	}

	function addOnce(source:Array<String>, target:Array<String>)
	{
		var temp = target.copy();
		for (node in source)
			if (target.indexOf(node) < 0) temp.push(node);
		return temp;
	}

	function unlink(g:Graph, name:String)
	{
		var pred = g.predecessors(name);
		if (pred == null) {
			trace('Cannot unlink $name');
			return;
		}
		for (p in pred)
			g.removeEdge(p, name);
	}
}