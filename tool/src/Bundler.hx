import ast.AstNode;
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
	static inline var REQUIRE = "var require = (function(r){ return function require(m) { return r[m]; } })($s.__registry__ || {});\n";
    static inline var SCOPE = "typeof exports != \"undefined\" ? exports : typeof window != \"undefined\" ? window : typeof self != \"undefined\" ? self : this";
	static inline var GLOBAL = "typeof window != \"undefined\" ? window : typeof global != \"undefined\" ? global : typeof self != \"undefined\" ? self : this";
	static inline var FUNCTION_START = "(function ($hx_exports, $global) { \"use-strict\";\n";
	static inline var FUNCTION_END = '})($SCOPE, $GLOBAL);\n';
	static inline var WP_START = '/* eslint-disable */ "use strict"\n';

	static var FRAGMENTS = {
		MAIN: {
			EXPORTS: "var $hx_exports = module.exports, $global = global;\n",
			SHARED: "var $s = $global.$hx_scope = $global.$hx_scope || {};\n"
		},
		CHILD: {
			EXPORTS: "var $hx_exports = module.exports, $global = global;\n",
			SHARED: "var $s = $global.$hx_scope, $_;\n"
		}
	}

	static final generateHtml:SourceMapConsumer->String->Array<String>->String = untyped global.generateHtml;

	final parser:Parser;
	final sourceMap:SourceMap;
	final extractor:Extractor;
	final reporter:Reporter;
	final minifyId:MinifyId;
	var commonjs:Bool;
	var debugSourceMap:Bool;
	var nodejsMode:Bool;
	var revMap:DynamicAccess<Array<Int>>;
	var idMap:DynamicAccess<Bool>;
	var bundles:Array<Bundle>;

	public function new(parser:Parser, sourceMap:SourceMap, extractor:Extractor, reporter:Reporter)
	{
		this.parser = parser;
		this.sourceMap = sourceMap;
		this.extractor = extractor;
		this.reporter = reporter;
		minifyId = new MinifyId();
	}

	public function generate(src:String, output:String, commonjs:Bool, debugSourceMap:Bool):Array<BundleResult>
	{
		this.commonjs = commonjs;
		this.debugSourceMap = sourceMap != null && debugSourceMap;

		bundles = [extractor.main].concat(extractor.bundles);

		// lookup-map between identifiers and bundles
		revMap = {};
		final len = bundles.length;
		for (i in 0...len) createRevMap(i, bundles[i]);

		// filter output nodes for each bundle
		buildIndex(src);

		// emit
		final results = [];
		for (i in 0...len) {
			final bundle = bundles[i];
			final isMain = bundle.isMain;
			final bundleOutput = isMain ? output : Path.join(Path.dirname(output), bundle.alias + '.js');
			trace('Emit $bundleOutput');

			final buffer = emitBundle(src, bundle, isMain);
			results[i] = {
				name: bundle.name,
				map: writeMap(bundleOutput, buffer),
				source: write(bundleOutput, buffer.src),
				debugMap: buffer.debugMap
			};
		}
		return results;
	}

	function buildIndex(src:String)
	{
		#if verbose_debug
		trace('Build index...');
		#end
		final ids = idMap = {};
		if (!commonjs) ids.set('require', true);
		final rev = revMap;
		final body = parser.rootBody;
		final bodyLength = body.length;
		final bundlesLength = bundles.length;
		for (i in 1...bodyLength)
		{
			final node = body[i];
			// Non-attributed nodes go in all bundles
			if (node.__tag__ == null) {
				#if verbose_debug
				trace('---[' + i + '] <unknown>');
				trace(src.substr(node.start, node.end - node.start));
				#end

				node.__main__ = true;
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
					final index = list[j];
					if (index == 0) node.__main__ = true;
					else bundles[index].indexes.push(i);
				}
			}
			// Reserved nodes go in Main bundle
			else node.__main__ = true;
		}

		#if verbose_debug
		trace('---[EOF]\nBundle indexes:');
		for (bundle in bundles)
			if (!bundle.isMain)
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
		// prevent minification of shared refs
		if (bundle.isLib) {
			for (param in bundle.libParams) minifyId.set(param);
		} else {
			minifyId.set(bundle.name);
		}
		// lookup-map between identifiers and bundles
		final rev = revMap;
		final nodes = bundle.nodes;
		final len = nodes.length;
		for (i in 0...len) {
			final list = rev.get(nodes[i]);
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
		final output = emitJS(src, bundle, isMain);
		final map = sourceMap != null ? sourceMap.emitMappings(output.mapNodes, output.mapOffset) : null;
		final debugMap = debugSourceMap && map != null ? emitDebugMap(output.buffer, bundle, map) : null;
		return {
			src:output.buffer,
			map:map,
			debugMap:debugMap
		}
	}

	function emitDebugMap(src:String, bundle:Bundle, rawMap:SourceMapFile)
	{
		if (rawMap.sources.length == 0) return null;
		// library doesn't like empty strings
		rawMap.sources = rawMap.sources.map(url -> url == '' ? null : url);

		final consumer = new SourceMapConsumer(rawMap);
		final sourcesContent = [for (source in rawMap.sources) {
			if (source == null || source == '') '';
			else {
				final fileName = source.split('file://').pop();
				Fs.readFileSync(fileName, 'utf8');
			}
		}];
		try {
			return generateHtml(consumer, src, sourcesContent);
		} catch (err: Dynamic) {
			// happens when a module is almost empty and has no mapped code at all
			trace('[WARNING] error while generating debug map for ${bundle.name}: ' + err);
			return null;
		}
	}

	function emitJS(src:String, bundle:Bundle, isMain:Bool)
	{
		reporter.start(bundle);

		final imports = bundle.imports.keys();
		final shared = bundle.shared.keys();
		final exports = bundle.exports.keys();
		final body = parser.rootBody;
		final hasSourceMap = sourceMap != null;
		var mapOffset = 0;
		var buffer = '';

		// include code before HaxeJS output only in main JS
		if (isMain) {
			buffer += getBeforeBodySrc(src);
			if (hasSourceMap) mapOffset += getBeforeBodyOffset();
		}
		else mapOffset++;

		final inc = bundle.nodes;
		final incAll = isMain && bundle.nodes.length == 0;
		final mapNodes:Array<AstNode> = [];
		final frag = isMain || bundle.isLib ? FRAGMENTS.MAIN : FRAGMENTS.CHILD;

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
			if (isMain) {
				// npm require stub
				buffer += REQUIRE;
				mapOffset++;
			}
		}
		if (imports.length > 0 || shared.length > 0)
		{
			final tmp = shared.concat([for (node in imports) '$node = $$s.${minifyId.get(node)}']);
			buffer += 'var ${tmp.join(', ')};\n';
			mapOffset++;
		}

		// split main content
		if (isMain)
		{
			final len = body.length - 1;
			for (i in 1...len)
			{
				final node = body[i];
				if (!incAll && !node.__main__)
					continue;
				if (hasSourceMap) mapNodes.push(node);
				final chunk = src.substr(node.start, node.end - node.start);
				reporter.add(node.__tag__, chunk.length);
				buffer += chunk;
				buffer += '\n';
			}
		}
		else
		{
			final indexes = bundle.indexes;
			final len = indexes.length;
			for (i in 0...len)
			{
				final node = body[indexes[i]];
				if (hasSourceMap) mapNodes.push(node);
				final chunk = src.substr(node.start, node.end - node.start);
				reporter.add(node.__tag__, chunk.length);
				buffer += chunk;
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
					buffer += '$$s.${minifyId.get(node)} = $node; ';
			buffer += '\n';
		}

		if (isMain)
		{
			// entry point
			final run = body[body.length - 1];
			buffer += src.substr(run.start, run.end - run.start);
			buffer += '\n';

			// main libs bridge
			for (bundle in extractor.bundles) {
				if (!bundle.isLib) continue;
				final match = '"${bundle.name}__BRIDGE__"';
				var bridge = bundle.exports.keys()
					.filter(node -> shared.indexOf(node) >= 0)
					.map(node -> '$node = $$s.${minifyId.get(node)}')
					.join(', ');
				if (bridge == '') bridge = '0';
				buffer = buffer.split(match).join('($bridge)');
			}
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
		final chunk = src.substr(0, parser.rootExpr.start);
		reporter.includedBefore(chunk.length);
		return chunk;
	}

	function emitHot(inc:Array<String>)
	{
		final names = [];
		for (name in parser.isHot.keys())
			if (parser.isHot.get(name) && inc.indexOf(name) >= 0) names.push(name);

		if (names.length == 0) return '';

		return 'if ($$global.__REACT_HOT_LOADER__)\n'
			+ '  [${names.join(",")}].map(function(c) {\n'
			+ '    __REACT_HOT_LOADER__.register(c,c.displayName,c.__fileName__);\n'
			+ '  });\n';
	}
}
