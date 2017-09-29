import acorn.Acorn.AstNode;
import js.node.Fs;
import js.node.Path;
import sourcemap.SourceMapGenerator;
import Extractor;

typedef OutputBuffer = {
	src:String,
	map:SourceMapGenerator
}

class Bundler
{
	static inline var REQUIRE = "var require = (function(r){ return function require(m) { return r[m]; } })($s.__registry__);\n";
    static inline var SCOPE = "typeof exports != \"undefined\" ? exports : typeof window != \"undefined\" ? window : typeof self != \"undefined\" ? self : this";
	static inline var GLOBAL = "typeof window != \"undefined\" ? window : typeof global != \"undefined\" ? global : typeof self != \"undefined\" ? self : this";
	static inline var FUNCTION = "function ($hx_exports, $global)";

	static var FRAGMENTS = {
		MAIN: {
			EXPORTS: "var $hx_exports = exports, $global = global;\n",
			SHARED: "var $s = $global.$hx_scope = $global.$hx_scope || {};\n"
		},
		CHILD: {
			EXPORTS: "var $hx_exports = exports, $global = global;\n",
			SHARED: "var $s = $global.$hx_scope;\n"
		}
	}

	var parser:Parser;
	var sourceMap:SourceMap;
	var extractor:Extractor;
	var webpackMode:Bool;

	public function new(parser:Parser, sourceMap:SourceMap, extractor:Extractor)
	{
		this.parser = parser;
		this.sourceMap = sourceMap;
		this.extractor = extractor;
	}

	public function generate(src:String, output:String, webpackMode:Bool)
	{
		this.webpackMode = webpackMode;

		trace('Emit $output');
		var result = [];
		var buffer = emitBundle(src, extractor.main, true);
		result.push({
			name: 'Main',
			map: writeMap(output, buffer),
			source: write(output, buffer.src)
		});

		for (bundle in extractor.bundles)
		{
			var bundleOutput = Path.join(Path.dirname(output), bundle.name + '.js');
			trace('Emit $bundleOutput');
			buffer = emitBundle(src, bundle, false);
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
		if (!Fs.statSync(output).isFile()) return true;
		var original = Fs.readFileSync(output).toString();
		return original != buffer;
	}

	function emitBundle(src:String, bundle:Bundle, isMain:Bool):OutputBuffer
	{
		var exports = bundle.exports;
		var buffer = webpackMode ? '/* eslint-disable */ "use strict"\n' : '';
		var body = parser.rootBody.copy();
		var head = body.shift();
		var run = isMain ? body.pop() : null;
		var inc = bundle.nodes;
		var incAll = isMain && bundle.nodes.length == 0;
		var mapNodes:Array<AstNode> = [];
		var mapOffset = 0;
		var frag = isMain || bundle.isLib ? FRAGMENTS.MAIN : FRAGMENTS.CHILD;

		// header
		if (webpackMode)
		{
			buffer += frag.EXPORTS;
			// shared scope
			buffer += frag.SHARED;
			mapOffset++;
		}
		else
		{
			buffer += verifyExport(src.substr(0, head.end + 1));
			// shared scope
			buffer += frag.SHARED;
			mapOffset++;
			// npm require
			buffer += REQUIRE;
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
}