import acorn.Acorn.AstNode;
import haxe.DynamicAccess;
import js.node.Fs;
import js.node.Path;
import SourceMap;
import Extractor;

typedef SourceResult<T> = {
	path:String,
	content:T
}

typedef BundleResult = {
	name:String,
	source:SourceResult<String>,
	map:SourceResult<SourceMapFile>,
	debugMap:String
}

typedef OutputBuffer = {
	src:String,
	map:SourceMapFile,
	?debugMap:String
}

@:jsRequire('source-map', 'SourceMapConsumer')
extern class SourceMapConsumer {
	public function new(map:SourceMapFile);
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
	var revMap:DynamicAccess<Array<Int>>;
	var idMap:DynamicAccess<Bool>;
	var bundles:Array<Bundle>;

	public function new(parser:Parser, sourceMap:SourceMap, extractor:Extractor)
	{
		this.parser = parser;
		this.sourceMap = sourceMap;
		this.extractor = extractor;
	}

	public function generate(src:String, output:String, commonjs:Bool, debugSourceMap:Bool):Array<BundleResult>
	{
		this.commonjs = commonjs;
		this.debugSourceMap = sourceMap != null && debugSourceMap;

		bundles = [extractor.main].concat(extractor.bundles);

		// lookup-map between identifiers and bundles
		revMap = {};
		var len = bundles.length;
		for (i in 0...len) createRevMap(i, bundles[i]);

		// filter output nodes for each bundle
		buildIndex(src);

		// emit
		var results = [];
		var isMain = true;
		for (i in 0...len) {
			var bundle = bundles[i];
			var bundleOutput = isMain ? output : Path.join(Path.dirname(output), bundle.name + '.js');
			trace('Emit $bundleOutput');

			var buffer = emitBundle(src, bundle, isMain);
			results[i] = {
				name: bundle.name,
				map: writeMap(bundleOutput, buffer),
				source: write(bundleOutput, buffer.src),
				debugMap: buffer.debugMap
			};
			isMain = false;
		}
		return results;
	}

	function buildIndex(src:String)
	{
		#if verbose_debug
		trace('Build index...');
		#end
		var ids = idMap = {};
		var rev = revMap;
		var body = parser.rootBody;
		var bodyLength = body.length;
		var bundlesLength = bundles.length;
		for (i in 1...bodyLength)
		{
			var node = body[i];
			// Non-attributed nodes go in all bundles
			if (node.__tag__ == null) {
				#if verbose_debug
				trace('---[' + i + '] <unknown>');
				trace(src.substr(node.start, node.end - node.start));
				#end

				node.__tag__ = '__reserved__'; // flag for Main
				for (j in 1...bundlesLength) {
					bundles[j].indexes.push(i);
				}
			}
			// Non-reserved nodes go in matching bundle
			else if (node.__tag__ != '__reserved__') {
				ids.set(node.__tag__, true);
				var list = rev.get(node.__tag__);
				if (list == null) list = [0];

				#if verbose_debug
				trace('---[' + i + '] ' + node.__tag__ + ' ' + list);
				trace(src.substr(node.start, node.end - node.start));
				#end

				for (j in 0...list.length) {
					var index = list[j];
					if (index == 0) node.__tag__ = '__reserved__';
					else bundles[index].indexes.push(i);
				}
			}
			// Reserved nodes go in Main bundle
		}

		#if verbose_debug
		trace('---[EOF]\nBundle indexes:');
		for (bundle in bundles)
			if (bundle.name != 'Main')
				trace('- ' + bundle.name + ': ' + bundle.indexes);
		trace('Bundle shared:');
		for (bundle in bundles)
			trace('- ' + bundle.name + ': ' + bundle.shared);
		trace('Bundle imported:');
		for (bundle in bundles)
			trace('- ' + bundle.name + ': ' + bundle.imports);
		#end
	}

	function createRevMap(index:Int, bundle:Bundle)
	{
		var rev = revMap;
		var nodes = bundle.nodes;
		var len = nodes.length;
		for (i in 0...len) {
			var list = rev.get(nodes[i]);
			if (list != null) list.push(index);
			else rev.set(nodes[i], [index]);
		}
	}

	function writeMap(output:String, buffer:OutputBuffer):SourceResult<SourceMapFile>
	{
		if (sourceMap == null || buffer.map == null) return null;
		return {
			path: '$output.map',
			content: sourceMap.emitFile(output, buffer.map)
		};
	}

	function write(output:String, buffer:String):SourceResult<String>
	{
		if (buffer == null) return null;
		return {
			path: output,
			content: buffer
		}
	}

	function emitBundle(src:String, bundle:Bundle, isMain:Bool):OutputBuffer
	{
		var output = emitJS(src, bundle, isMain);
		var map = sourceMap != null ? sourceMap.emitMappings(output.mapNodes, output.mapOffset) : null;
		var debugMap = debugSourceMap && map != null ? emitDebugMap(output.buffer, bundle, map) : null;
		return {
			src:output.buffer,
			map:map,
			debugMap:debugMap
		}
	}

	function emitDebugMap(src:String, bundle:Bundle, rawMap:SourceMapFile)
	{
		if (rawMap.sources.length == 0) return null;

		var consumer = new SourceMapConsumer(rawMap);
		var sources = [for (source in rawMap.sources) {
			if (source == null) '';
			else {
				var fileName = source.split('file://').pop();
				Fs.readFileSync(fileName).toString();
			}
		}];
		return generateHtml(consumer, src, sources);
	}

	function emitJS(src:String, bundle:Bundle, isMain:Bool)
	{
		var mapOffset = 0;
		var exports = bundle.exports;
		var buffer = '';
		var body = parser.rootBody;
		var hasSourceMap = sourceMap != null;

		// include code before HaxeJS output only in main JS
		if (isMain) {
			buffer += getBeforeBodySrc(src);
			if (hasSourceMap) mapOffset += getBeforeBodyOffset();
		}
		else mapOffset++;

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
		if (isMain)
		{
			var len = body.length - 1;
			for (i in 1...len)
			{
				var node = body[i];
				if (!incAll && node.__tag__ != '__reserved__')
					continue;
				if (hasSourceMap) mapNodes.push(node);
				buffer += src.substr(node.start, node.end - node.start);
				buffer += '\n';
			}
		}
		else
		{
			var indexes = bundle.indexes;
			var len = indexes.length;
			for (i in 0...len)
			{
				var node = body[indexes[i]];
				if (hasSourceMap) mapNodes.push(node);
				buffer += src.substr(node.start, node.end - node.start);
				buffer += '\n';
			}
		}

		// hot-reload
		if (parser.isHot != null) buffer += emitHot(inc);

		// reference shared types
		if (exports.length > 0)
		{
			for (node in exports)
				if (node.charAt(0) == '$' || idMap.exists(node))
					buffer += '$$s.$node = $node; ';
			buffer += '\n';
		}

		// entry point
		if (isMain)
		{
			var run = body[body.length - 1];
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
