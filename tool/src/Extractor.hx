package;

import graphlib.Graph;
import haxe.DynamicAccess;

typedef Bundle = {
	isLib:Bool,
	name:String,
	nodes:Array<String>,
	indexes:Array<Int>,
	exports:Array<String>,
	shared:Array<String>,
	imports:Array<String>
}

class Extractor
{
	public var main(default, null):Bundle;
	public var bundles(default, null):Array<Bundle> = [];

	var parser:Parser;
	var g:Graph;
	var hmrMode:Bool;
	var mainModule:String;
	var modules:Array<String>;
	var moduleRefs:DynamicAccess<Array<String>>;
	var mainNodes:Array<String>;
	var mainExports:Array<String>;

	public function new(parser:Parser)
	{
		this.parser = parser;
	}

	public function process(mainModule:String, modulesList:Array<String>, debugMode:Bool)
	{
		trace('Bundling...');

		if (parser.typesCount == 0) {
			setEmptyMain();
			return;
		}

		// context
		g = parser.graph;
		hmrMode = debugMode;
		this.mainModule = mainModule;
		uniqueModules(modulesList);

		// apply policy with orphan nodes
		linkOrphans();

		// separate modules graphs
		unlinkModules();

		// find main nodes
		findMainNodes();

		// find modules nodes
		bundles = modules.map(processModule);

		// extract common nodes
		extractCommonNodes();

		finaliseMain();
	}

	function finaliseMain()
	{
		// resolve who loads what
		var mainImports = resolveImports();

		main = {
			isLib: false,
			name: 'Main',
			nodes: mainNodes,
			indexes: [],
			exports: mainExports,
			shared: [],
			imports: mainImports
		}
	}

	function extractCommonNodes()
	{
		// hoist common nodes into main bundle
		var dupes = deduplicate();
		mainNodes = addOnce(mainNodes, dupes.removed);
		mainExports = dupes.shared;

		for (bundle in bundles) {
			if (bundle.isLib) {
				mainNodes = remove(bundle.nodes, mainNodes);
				mainExports = remove(bundle.nodes, mainExports);
				bundle.exports = bundle.nodes.copy();
			}
		}
	}

	function findMainNodes()
	{
		// find main nodes
		mainNodes = Alg.preorder(g, mainModule);

		// /!\ force hoist enums in main bundle to avoid HMR conflicts
		if (hmrMode)
			for (key in parser.isEnum.keys()) mainNodes.push(key);
	}

	function unlinkModules()
	{
		// create separated sub-trees for main and modules bundles
		moduleRefs = {};
		for (module in modules) {
			moduleRefs.set(module, g.predecessors(module));
			unlink(g, module);
		}
	}

	function uniqueModules(modulesList:Array<String>)
	{
		// deduplicate modules
		modules = [];
		for (module in modulesList)
			if (modules.indexOf(module) < 0) modules.push(module);
	}

	function linkOrphans()
	{
		// link "orphan" classes to main module
		var sources = g.sources();
		for (source in sources)
			if (source != mainModule)
				g.setEdge(mainModule, source);

		// force some links to main module
		for (enforce in ["$estr", "$hxClasses"]) {
			if (g.hasNode(enforce) && !g.hasEdge(mainModule, enforce))
				g.setEdge(mainModule, enforce);
		}
	}

	function setEmptyMain()
	{
		trace('Warning: unable to process (no type metadata)');
		main = {
			isLib: false,
			name: 'Main',
			nodes: [],
			indexes: [],
			exports: [],
			shared: [],
			imports: []
		};
	}

	function processModule(name:String):Bundle
	{
		// set up initial bundle objects with needs of used nodes
		if (name.indexOf('=') > 0) {
			// package extraction
			var parts = name.split('=');
			var test = new EReg('^${parts[1].split(",").join("|")}', '');
			var ret = {
				isLib: true,
				name: parts[0],
				nodes: g.nodes().filter(function (n) return test.match(n)),
				indexes: [],
				exports: [],
				shared: [],
				imports: []
			};
			return ret;
		}
		else return {
			isLib: false,
			name: name,
			nodes: Alg.preorder(g, name),
			indexes: [],
			exports: [name],
			shared: [],
			imports: []
		}
	}

	function resolveImports()
	{
		// find if bundles load other bundles
		var mainImports = [];
		var mainBundle = cast {
			names: 'Main',
			nodes: mainNodes
		};
		for (module in moduleRefs.keys()) {
			var names = moduleRefs.get(module);
			for (bundle in bundles) {
				if (isReferenced(names, bundle)) {
					bundle.imports = addOnce([module], bundle.imports);
				}
			}
			if (isReferenced(names, mainBundle)) {
				mainImports = addOnce([module], mainImports);
			}
		}
		return mainImports;
	}

	function isReferenced(names:Array<String>, bundle:Bundle)
	{
		if (names == null || names.length == 0) return false;

		for (name in names) {
			if (bundle.name == name) return true;
			if (bundle.nodes.indexOf(name) >= 0) return true;
		}
		return false;
	}

	function deduplicate()
	{
		trace('Extract common chunks...' + (hmrMode ? ' (fast)' : ''));

		// map the nodes referenced in several bundles
		// /!\ in debug mode, only deduplicate nodes in the main bundle to allow HMR of shared components
		var map = new Map<String, Bool>();
		for (node in mainNodes) map.set(node, true);
		var dupes = [];
		for (bundle in bundles)
		{
			for (node in bundle.nodes) {
				if (map.exists(node)) {
					if (dupes.indexOf(node) < 0) dupes.push(node);
				}
				else if (bundle.isLib || !hmrMode) map.set(node, true);
			}
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
			if (!bundle.isLib) {
				bundle.nodes = bundle.nodes.filter(function(node) {
					if (dupes.indexOf(node) < 0) return true;
					if (shared.indexOf(node) >= 0) bundle.shared.push(node);
					return false;
				});
			}
		}

		trace('Moved ${dupes.length} common chunks (${shared.length} shared)');
		return {
			removed:dupes,
			shared:shared
		}
	}

	function remove(source:Array<String>, target:Array<String>)
	{
		return source.filter(function(node) return target.indexOf(node) < 0);
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
		if (name.indexOf('=') > 0) return;

		var pred = g.predecessors(name);
		if (pred == null) {
			trace('Cannot unlink $name');
			return;
		}
		for (p in pred)
			g.removeEdge(p, name);
	}
}