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
    static inline var SCOPE = "typeof $hx_scope != \"undefined\" ? $hx_scope : $hx_scope = {}";
	static inline var GLOBAL = "typeof window != \"undefined\" ? window : typeof global != \"undefined\" ? global : typeof self != \"undefined\" ? self : this";
	static inline var FUNCTION = "function ($hx_exports, $global)";

	static var FRAGMENTS = {
		MAIN: {
			EXPORTS: "var $hx_exports = global.$hx_exports = global.$hx_exports || {__shared__:{}}, $s = $hx_exports.__shared__;\n",
			SHARED: "var $s = $hx_exports.__shared__ = $hx_exports.__shared__ || {};\n"
		},
		CHILD: {
			EXPORTS: "var $hx_exports = global.$hx_exports, $s = $hx_exports.__shared__;\n",
			SHARED: "var $s = $hx_exports.__shared__;\n"
		}
	}

	var parser:Parser;
	var sourceMap:SourceMap;
	var main:Bundle;
	var mainExports:Array<String>;
	var bundles:Array<Bundle> = [];
	var webpackMode:Bool;

	public function new(parser:Parser, sourceMap:SourceMap)
	{
		this.parser = parser;
		this.sourceMap = sourceMap;
	}

	public function generate(src:String, output:String, webpackMode:Bool)
	{
		this.webpackMode = webpackMode;

		trace('Emit $output');
		var result = [];
		var buffer = emitBundle(src, main, mainExports, true);
		result.push({
			name: 'Main',
			map: writeMap(output, buffer),
			source: write(output, buffer.src)
		});

		for (bundle in bundles)
		{
			var bundleOutput = Path.join(Path.dirname(output), bundle.name + '.js');
			trace('Emit $bundleOutput');
			buffer = emitBundle(src, bundle, [bundle.name], false);
			result.push({
				name: bundle.name,
				map: writeMap(bundleOutput, buffer),
				source: write(bundleOutput, buffer.src)
			});
		}

		return result;
	}

	function writeMap(output:String, buffer:OutputBuffer)
	{
		if (buffer.map == null) return null;
		return {
			path: '$output.map',
			content: sourceMap.emitFile(output, buffer.map).toString()
		};
	}

	function write(output:String, buffer:String)
	{
		if (buffer == null) return null;
		return {
			path: output,
			content: buffer
		}
	}

	function hasChanged(output:String, buffer:String)
	{
		if (!Fs.existsSync(output)) return true;
		var original = Fs.readFileSync(output).toString();
		return original != buffer;
	}

	function emitBundle(src:String, bundle:Bundle, exports:Array<String>, isMain:Bool):OutputBuffer
	{
		var buffer = webpackMode ? '/* eslint-disable */ "use strict"\n' : '';
		var body = parser.rootBody.copy();
		var head = body.shift();
		var run = isMain ? body.pop() : null;
		var inc = bundle.nodes;
		var incAll = isMain && bundle.nodes.length == 0;
		var mapNodes:Array<AstNode> = [];
		var mapOffset = 0;
		var frag = isMain ? FRAGMENTS.MAIN : FRAGMENTS.CHILD;

		// header
		if (webpackMode)
		{
			buffer += frag.EXPORTS;
		}
		else
		{
			buffer += verifyExport(src.substr(0, head.end + 1));
			// shared scope
			buffer += REQUIRE;
			mapOffset++;
			buffer += frag.SHARED;
			mapOffset++;
		}
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
			if (!incAll && node.__tag__ != null && inc.indexOf(node.__tag__) < 0) {
				if (!isMain || node.__tag__ != '__reserved__')
					continue;
			}
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

		if (!webpackMode) buffer += '})($SCOPE, $GLOBAL);\n';

		return {
			src:buffer,
			map:sourceMap.emitMappings(mapNodes, mapOffset)
		}
	}

	function emitHot(inc:Array<String>)
	{
		var names = [];
		for (name in parser.isHot.keys())
			if (parser.isHot.get(name) && inc.indexOf(name) >= 0) names.push(name);

		if (names.length == 0) return '';

		return 'if ($$global.__REACT_HOT_LOADER__)\n'
			+ '  [${names.join(",")}].map(function(c) {\n'
			+ '    __REACT_HOT_LOADER__.register(c,c.displayName,c.__fileName__);\n'
			+ '  });\n';
	}

	function verifyExport(s:String)
	{
		return ~/function \([^)]*\)/.replace(s, FUNCTION);
	}

	public function process(mainModule:String, modules:Array<String>, debugMode:Bool)
	{
		if (parser.typesCount == 0) {
			trace('Warning: unable to process (no type metadata)');
			main = {
				name: 'Main',
				nodes: [],
				shared: []
			};
			mainExports = [];
			return;
		}

		trace('Bundling...');
		var g = parser.graph;

		// create separated sub-trees for main and modules bundles
		for (module in modules)
			unlink(g, module);

		// find main nodes
		var mainNodes = Alg.preorder(g, mainModule);

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