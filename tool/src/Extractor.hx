package;

import graphlib.Graph;
import haxe.DynamicAccess;

typedef Bundle = {
	isMain:Bool,
	isLib:Bool,
	name:String,
	nodes:Array<String>,
	indexes:Array<Int>,
	exports:DynamicAccess<Bool>,
	shared:DynamicAccess<Bool>,
	imports:DynamicAccess<Bool>
}

typedef LibTest = { test:Array<String>, roots:DynamicAccess<Bool>, bundle:Bundle };

class Extractor
{
	public var main(default, null):Bundle;
	public var bundles(default, null):Array<Bundle>;
	public var mainLibs:Map<String, Array<String>>;

	var parser:Parser;
	var g:Graph;
	var hmrMode:Bool;
	var mainModule:String;
	var modules:Array<String>;
	var moduleRefs:DynamicAccess<Array<String>>;
	var mainNodes:Array<String>;
	var mainImports:Array<String>;
	var mainExports:Array<String>;
	var libsNodes:Array<String>;
	var libMap:DynamicAccess<LibTest>;
	var moduleTest:DynamicAccess<Bool>;
	var parenting:Graph;
	var moduleMap:DynamicAccess<Bundle>;

	public function new(parser:Parser)
	{
		this.parser = parser;
	}

	public function process(mainModule:String, modulesList:Array<String>, debugMode:Bool)
	{
		var t0 = Date.now().getTime();
		trace('Bundling...');
		moduleMap = {};
		parenting = new Graph();
		moduleTest = {};

		if (parser.typesCount == 0) {
			trace('Warning: unable to process (no type metadata)');
			main = createBundle(mainModule);
			bundles = [main];
			return;
		}

		// context
		g = parser.graph;
		hmrMode = debugMode;
		this.mainModule = mainModule;
		uniqueModules(modulesList);
		for (module in modulesList) moduleTest.set(module, true);

		// apply policy with orphan nodes
		linkOrphans();

		// apply policy of debug mode
		if (debugMode) linkEnums(mainModule, parser.isEnum.keys());

		// find libs
		var libTest:Array<LibTest> = expandLibs();

		// process graph
		var parents = {};
		recurseVisit([mainModule], libTest, parents);
		recurseVisit(modules, libTest, parents); // modules can be isolated from entry point
		walkLibs(libTest, parents);
		populateBundles(mainModule, parents);

		// format results
		main = moduleMap.get(mainModule);
		bundles = modules.map(function(module) {
			var name = module.indexOf('=') > 0 ? module.split('=')[0] : module;
			return moduleMap.get(name);
		}).filter(function(bundle) return bundle != null);

		var t1 = Date.now().getTime();
		trace('Graph processed in: ${t1 - t0}ms');
		#if debug
		trace(main);
		trace(bundles);
		#end
	}

	function deduplicate(a:Array<String>)
	{
		if (a.length <= 1) return a;
		var b = [];
		var known:DynamicAccess<Bool> = {};
		for (s in a) {
			if (!known.exists(s)) {
				b.push(s);
				known.set(s, true);
			}
		}
		b.sort(null);
		return b;
	}

	function populateBundles(mainModule:String, parents:DynamicAccess<String>)
	{
		// Now that nodes having attributed to bundles,
		// re-walk the graph to populate bundles' nodes/exports/imports/shared
		var bundle = moduleMap.get(mainModule);
		recursePopulate(bundle, mainModule, parents, {});
	}

	function recursePopulate(bundle:Bundle, root:String, parents:DynamicAccess<String>, visited:DynamicAccess<Bool>)
	{
		bundle.nodes.push(root);
		var module = bundle.name;
		var succ = g.successors(root);
		var parent:Bundle;
		for (node in succ) {
			// find node owner
			var parentModule = parents.get(node);
			if (parentModule == module) {
				// same bundle
				parent = bundle;
			}
			else {
				// node is owned by another bundle and has to be exported
				parent = moduleMap.get(parentModule);
				if (bundle.isMain) {
					// we can't import sub-modules/classes in main module
					bundle.shared.set(node, true);
				}
				else if (node == parentModule) {
					// if it's a child bundle entry point, then it's shared (by the child)
					if (parenting.hasEdge(module, parentModule)) bundle.shared.set(node, true);
					// otherwise, it's a parent bundle and we can import it
					else bundle.imports.set(node, true);
				}
				// class is part of another module
				else bundle.imports.set(node, true);
				parent.exports.set(node, true);
			}
			// tag and recurse
			if (visited.exists(node)) continue;
			visited.set(node, true);
			recursePopulate(parent, node, parents, visited);
		}
	}

	function walkLibs(libTest:Array<LibTest>, parents:DynamicAccess<String>)
	{
		// libs don't have a single root, any number of disconnected classes can be referenced
		var children = [];
		for (lib in libTest) {
			for (node in lib.roots.keys()) {
				var test = libTest.filter(function(it) return it != lib);
				if (parents.exists(node)) continue;
				parents.set(node, lib.bundle.name);
				walkGraph(lib.bundle, [node], test, parents, children);
			}
		}
	}

	function recurseVisit(modules:Array<String>, libTest:Array<LibTest>, parents:DynamicAccess<String>)
	{
		var children = [];
		for (module in modules) {
			if (module.indexOf('=') > 0 || moduleMap.exists(module) || !g.hasNode(module)) continue;
			var mod = createBundle(module);
			parents.set(module, module);
			walkGraph(mod, [module], libTest, parents, children);
		}
		if (children.length > 0) recurseVisit(children, libTest, parents);
	}

	function walkGraph(bundle:Bundle, stack:Array<String>, libTest:Array<LibTest>, parents:DynamicAccess<String>, children:Array<String>)
	{
		if (stack.length == 0) return;
		var module = bundle.name;
		var target = stack.pop();
		var succ = g.successors(target);
		for (node in succ) {
			// reached sub modules
			if (moduleTest.exists(node)) {
				var childModule = node;
				// create only edge from parent to child
				if (!parenting.hasEdge(childModule, module)) {
					parenting.setEdge(module, childModule);
					children.push(childModule);
				}
				continue;
			}
			// reached lib
			if (isInLib(node, libTest)) {
				continue;
			}
			// deduplicate
			if (parents.exists(node)) {
				var ownerModule = parents.get(node);
				if (ownerModule == module) continue;
				var owner = moduleMap.get(ownerModule);
				if (!owner.isMain) {
					var parentModule = commonParent(bundle, owner);
					var parent = moduleMap.get(parentModule);
					shareGraph(parent, owner, node, parents);
				}
				continue;
			}
			// tag and recurse
			parents.set(node, module);
			stack.push(node);
		}
		walkGraph(bundle, stack, libTest, parents, children);
	}

	function shareGraph(toBundle:Bundle, fromBundle:Bundle, root:String, parents:DynamicAccess<String>)
	{
		// A node was found to be referenced by 2 bundles:
		// it should be hoisted in the parent bundle, along with its children
		var toModule = toBundle.name;
		var fromModule = fromBundle.name;
		parents.set(root, toModule);
		var succ = g.successors(root);
		for (node in succ) {
			var current = parents.get(node);
			if (current == fromModule) {
				shareGraph(toBundle, fromBundle, node, parents);
			}
		}
	}

	function commonParent(b1:Bundle, b2:Bundle)
	{
		var p1 = parentsOf(b1.name, {});
		var p2 = parentsOf(b2.name, {});
		var i1 = p1.length - 1;
		var i2 = p2.length - 1;
		var parent = mainModule;
		while (p1[i1] == p2[i2]) {
			parent = p1[i1];
			i1--;
			i2--;
		}
		return parent;
	}

	function parentsOf(module:String, visited:DynamicAccess<Bool>)
	{
		var pred = parenting.predecessors(module);
		var best:Array<String> = null;
		for (p in pred) {
			if (visited.exists(p)) continue;
			visited.set(p, true);
			var parents = parentsOf(p, visited);
			if (best == null) best = parents;
			else if (parents.length < best.length) best = parents;
		}
		if (best == null) best = [mainModule];
		else best.unshift(module);
		return best;
	}

	inline function isInLib(node:String, libTest:Array<LibTest>)
	{
		var lib = libMap.get(node);
		if (lib != null && libTest.indexOf(lib) >= 0) {
			lib.roots.set(node, true);
			return true;
		}
		return false;
	}

	function uniqueModules(modulesList:Array<String>)
	{
		// deduplicate modules
		modules = [];
		for (module in modulesList)
			if (modules.indexOf(module) < 0) modules.push(module);
	}

	function linkEnums(root:String, list:Array<String>)
	{
		// force enums in main bundle in debug mode to allow hot-code reload
		for (node in list)
			g.setEdge(root, node);
	}

	function linkOrphans()
	{
		// link "orphan" classes to main module
		var sources = g.sources();
		for (source in sources)
			if (source != mainModule)
				g.setEdge(mainModule, source);

		// force some links to main module
		for (enforce in ["$estr", "$hxClasses", "Std"]) {
			if (!g.hasNode(enforce)) continue;
			if (!g.hasEdge(mainModule, enforce))
				g.setEdge(mainModule, enforce);
		}
	}

	function createBundle(name:String, isLib:Bool = false)
	{
		var bundle:Bundle = {
			isMain: name == mainModule,
			isLib: isLib,
			name: name,
			nodes: [],
			indexes: [],
			exports: {},
			shared: {},
			imports: {}
		};
		if (!parenting.hasNode(name)) parenting.setNode(name);
		moduleMap.set(name, bundle);
		return bundle;
	}

	function expandLibs()
	{
		libMap = {};
		var libTest:Array<LibTest> = [];
		var allNodes = parser.graph.nodes();
		for (i in 0...modules.length) {
			var module = modules[i];
			if (module.indexOf('=') > 0) {
				var lib = resolveLib(module);
				mapLibTypes(allNodes, lib);
				libTest.push(lib);
			}
		}
		return libTest;
	}

	function mapLibTypes(allNodes:Array<String>, lib:LibTest)
	{
		// match each node with owning lib
		var test = lib.test;
		var n = test.length;
		for (i in 0...allNodes.length) {
			var node = allNodes[i];
			for (j in 0...n) {
				// use JS native `startsWith`
				if (untyped node.startsWith(test[j])) {
					libMap.set(node, lib);
					break;
				}
			}
		}
	}

	function resolveLib(name:String):LibTest
	{
		// libname=pattern
		var parts = name.split('=');
		var newName = parts[0];
		return {
			test: parts[1].split(','),
			roots: ({} :DynamicAccess<Bool>),
			bundle: createBundle(newName, true)
		};
	}

	function addOnce(source:Array<String>, target:Array<String>)
	{
		var temp = target.copy();
		for (node in source)
			if (target.indexOf(node) < 0) temp.push(node);
		return temp;
	}
}