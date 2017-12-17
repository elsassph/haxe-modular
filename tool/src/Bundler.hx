import acorn.Acorn.AstNode;
import haxe.Json;
import js.node.Fs;
import js.node.Path;
import sourcemap.SourceMapConsumer;
import sourcemap.SourceMapGenerator;
import SourceMap;
import Extractor;

typedef SourceResult = {
	path:String,
	content:String
}

typedef BundleResult = {
	name:String,
	src:SourceResult,
	map:SourceResult,
	debugMap:String
}

typedef OutputBuffer = {
	src:String,
	map:SourceMapGenerator,
	?debugMap:String
}

class Bundler
{
	static inline var REQUIRE = "var require = (function(r){ return function require(m) { return r[m]; } })($s.__registry__);\n";
    static inline var SCOPE = "typeof exports != \"undefined\" ? exports : typeof window != \"undefined\" ? window : typeof self != \"undefined\" ? self : this";
	static inline var GLOBAL = "typeof window != \"undefined\" ? window : typeof global != \"undefined\" ? global : typeof self != \"undefined\" ? self : this";
	static inline var FUNCTION_START = "(function ($hx_exports, $global) { \"use-strict\";\n";
	static inline var FUNCTION_END = '})($SCOPE, $GLOBAL);\n';
	static inline var WP_START = '/* eslint-disable */ "use strict"\n';

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

	static var generateHtml:SourceMapConsumer->String->Array<String>->String = untyped global.generateHtml;

	var parser:Parser;
	var sourceMap:SourceMap;
	var extractor:Extractor;
	var commonjs:Bool;
	var debugSourceMap:Bool;
	var nodejsMode:Bool;

	public function new(parser:Parser, sourceMap:SourceMap, extractor:Extractor)
	{
		this.parser = parser;
		this.sourceMap = sourceMap;
		this.extractor = extractor;
	}

	public function generate(src:String, output:String, commonjs:Bool, debugSourceMap:Bool)
	{
		this.commonjs = commonjs;
		this.debugSourceMap = debugSourceMap;

		trace('Emit $output');
		var result = [];
		var buffer = emitBundle(src, extractor.main, true);
		result.push({
			name: 'Main',
			map: writeMap(output, buffer),
			source: write(output, buffer.src),
			debugMap: buffer.debugMap
		});

		for (bundle in extractor.bundles)
		{
			var bundleOutput = Path.join(Path.dirname(output), bundle.name + '.js');
			trace('Emit $bundleOutput');
			buffer = emitBundle(src, bundle, false);
			result.push({
				name: bundle.name,
				map: writeMap(bundleOutput, buffer),
				source: write(bundleOutput, buffer.src),
				debugMap: buffer.debugMap
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

	function write(output:String, buffer:String):SourceResult
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
		var output = emitJS(src, bundle, isMain);
		var map = sourceMap.emitMappings(output.mapNodes, output.mapOffset);
		var debugMap = debugSourceMap ? emitDebugMap(output.buffer, bundle, map) : null;
		return {
			src:output.buffer,
			map:map,
			debugMap:debugMap
		}
	}

	function emitDebugMap(src:String, bundle:Bundle, map:SourceMapGenerator)
	{
		var rawMap:SourceMapFile = Json.parse(map.toString());
		var consumer = new SourceMapConsumer(rawMap);
		var sources = [for (source in rawMap.sources) {
			var fileName = source.split('file:///').pop();
			if (Sys.systemName() != 'Windows') fileName = '/' + fileName;
			Fs.readFileSync(fileName).toString();
		}];
		return generateHtml(consumer, src, sources);
	}

	function emitJS(src:String, bundle:Bundle, isMain:Bool)
	{
		var mapOffset = 0;
		var exports = bundle.exports;
		var buffer = '';
		var body = parser.rootBody.copy();

		body.shift(); // "use strict"

		// include code before HaxeJS output only in main JS
		if (isMain) {
			buffer += getBeforeBodySrc(src);
			mapOffset += getBeforeBodyOffset();
		}
		else mapOffset++;

		var run = isMain ? body.pop() : null;
		var inc = bundle.nodes;
		var incAll = isMain && bundle.nodes.length == 0;
		var mapNodes:Array<AstNode> = [];
		var frag = isMain || bundle.isLib ? FRAGMENTS.MAIN : FRAGMENTS.CHILD;

		// header
		if (commonjs)
		{
			buffer += WP_START;
			mapOffset++;
			buffer += frag.EXPORTS;
			mapOffset++;
			// shared scope
			buffer += frag.SHARED;
			mapOffset++;
		}
		else
		{
			buffer += FUNCTION_START;
			mapOffset++;
			// shared scope
			buffer += frag.SHARED;
			mapOffset++;
			// npm require stub
			buffer += REQUIRE;
			mapOffset++;
		}
		if (bundle.imports.length > 0 || bundle.shared.length > 0)
		{
			var tmp = bundle.imports.concat(isMain
				? bundle.shared
				: [for (node in bundle.shared) '$node = $$s.$node']);
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

		if (!commonjs) buffer += FUNCTION_END;

		return {
			buffer:buffer,
			mapNodes:mapNodes,
			mapOffset:mapOffset
		};
	}

	function getBeforeBodyOffset()
	{
		return parser.rootExpr.loc.start.line;
	}

	function getBeforeBodySrc(src:String)
	{
		return src.substr(0, parser.rootExpr.start);
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
}