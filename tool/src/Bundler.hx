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
	static inline var SCOPE = "})(typeof $hx_scope != \"undefined\" ? $hx_scope : $hx_scope = {});\n";

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
			for (node in bundle.shared)
				buffer += 'var $node = $$s.$node; ';
			buffer += '\n';
			mapOffset++;
		}
		
		for (node in body)
		{
			if (node.__tag__ != null && inc.indexOf(node.__tag__) < 0)
				continue;
			mapNodes.push(node);
			buffer += src.substr(node.start, node.end - node.start);
			buffer += '\n';
		}
		
		if (exports.length > 0)
		{
			for (node in exports)
				buffer += '$$s.$node = $node; ';
			buffer += '\n';
		}
		
		if (run != null)
		{
			buffer += src.substr(run.start, run.end - run.start);
			buffer += '\n';
		}
		
		buffer += SCOPE;
		return {
			src:buffer,
			map:sourceMap.emitMappings(mapNodes, mapOffset)
		}
	}
	
	function verifyExport(s:String) 
	{
		return ~/function \([^)]*\)/.replace(s, 'function ($$hx_exports)');
	}
	
	public function process(modules:Array<String>) 
	{
		trace('Bundling...');
		var g = parser.graph;
		
		// create sub-trees for main and modules
		for (module in modules)
			unlink(g, module);
		
		// find main nodes
		var mainNodes = Alg.preorder(g, 'Main');
		var exports = [];
		
		// find modules nodes
		for (module in modules)
		{
			var nodes = Alg.preorder(g, module);
			var shared = nodes.filter(function(v) return mainNodes.indexOf(v) >= 0);
			nodes = nodes.filter(function(v) return shared.indexOf(v) < 0);
			exports = addOnce(shared, exports);
			bundles.push({
				name: module,
				nodes: nodes,
				shared: shared
			});
		}
		
		main = {
			name: 'Main',
			nodes: mainNodes,
			shared: modules
		}
		mainExports = exports;
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
		for (p in pred)
			g.removeEdge(p, name);
	}
}