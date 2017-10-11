// Generated by Haxe 3.4.2 (git build master @ 890f8c7)
if (process.version < "v4.0.0") console.warn("Module " + (typeof(module) == "undefined" ? "" : module.filename) + " requires node.js version 4.0.0 or higher");
(function() {

// From: https://github.com/sokra/source-map-visualization

// app.less
var CSS = `
* {
	font-family: Monaco,Menlo,Consolas,Courier New,monospace;
	font-size: 12px;
}
span.original-item {
	border-left: 1px solid black;
	margin: 1px;
	min-width: 3px;
}
span.generated-item {
	margin: 1px;
}
span.selected {
	background: black;
	color: white;
}
.style-0 {
	background: #FFFF66;
}
.style-1 {
	background: #FFFFFF;
}
.style-2 {
	background: #FFBBBB;
}
.style-3 {
	background: #AAFFFF;
}
.style-4 {
	background: #FFAAFF;
}

pre {
	overflow-x: auto;
}

pre code {
	white-space: pre-wrap;
	word-break: normal;
	word-wrap: normal;
}

table {
	width: 100%;
}

tr, td {
	vertical-align: top;
	margin: 0;
	width: 33%;
}`;

// app.js, after HTML generation
var SCRIPT = `
	$("body").delegate(".original-item, .generated-item, .mapping-item", "mouseenter", function() {
		$(".selected").removeClass("selected");
		var mappedItems = $(this).data('mapped');
		if (!mappedItems){
			var source = $(this).data("source");
			var line = $(this).data("line");
			var column = $(this).data("column");
			mappedItems = $(".item-" + source + "-" + line + "-" + column);
			var twinItem = mappedItems.not('.mapping-item').not(this);
			$(this).data('mapped', mappedItems)
			$(this).data('twin', twinItem)
		}
		$(mappedItems).addClass("selected");
	}).delegate(".original-item, .generated-item, .mapping-item", "click", function() {
		var twinItem = $(this).data('twin');
		var elem = $(twinItem).get(0)
		if (elem && elem.scrollIntoViewIfNeeded)
			elem.scrollIntoViewIfNeeded();
	});
`;


// generateHtml.js
var SourceMap = require("source-map");
var LINESTYLES = 5;
var MAX_LINES = 5000;

function formatSource(source) {
	return source.replace(/</g, "&lt;").split('/').pop();
}

global.generateHtml = function(map, generatedCode, sources) {
	var generatedSide = [];
	var originalSide = [];
	var mappingsSide = [];

	function addTo(side, line, html) {
		side[line] = (side[line] || "") + html;
	}

	function span(text, options) {
		var attrs = {};
		if(options) {
			if(options.generated) {
				attrs["class"] = "generated-item";
			} else if(options.mapping) {
				attrs["class"] = "mapping-item";
			} else {
				attrs["class"] = "original-item";
			}
			if(typeof options.source !== "undefined") {
				attrs["class"] += " item-" + options.source + "-" + options.line + "-" + options.column;
			}
			attrs["class"] += " style-" + (options.line%LINESTYLES);
			if (options.name) attrs["title"] = options.name;
			attrs["data-source"] = options.source;
			attrs["data-line"] = options.line;
			attrs["data-column"] = options.column;
		}
		return "<span " + Object.keys(attrs).filter(function(key) {
			return typeof attrs[key] !== "undefined";
		}).map(function(key) {
			return key + "=\"" + attrs[key] + "\"";
		}).join(" ") + ">" + (text + "").replace(/</g, "&lt;") + "</span>";
	}

	var mapSources = map.sources;

	var generatedLine = 1;
	var nodes = SourceMap.SourceNode.fromStringWithSourceMap(generatedCode, map).children;
	nodes.forEach(function(item, idx) {
		if(generatedLine > MAX_LINES) return;
		if(typeof item === "string") {
			item.split("\n").forEach(function(line) {
				addTo(generatedSide, generatedLine, line);
				generatedLine++;
			});
			generatedLine--;
		} else {
			var str = item.toString();
			var source = mapSources.indexOf(item.source);
			str.split("\n").forEach(function(line) {
				addTo(generatedSide, generatedLine, span(line, {
					generated: true,
					source: source,
					line: item.line,
					column: item.column,
					name: item.name
				}));
				generatedLine++
			});
			generatedLine--;
		}
	});


	var lastGenLine = 1;
	var lastOrgSource = "";
	var mappingsLine = 1;
	map.eachMapping(function(mapping) {
		if(mapping.generatedLine > MAX_LINES) return;
		while(lastGenLine < mapping.generatedLine) {
			mappingsLine++;
			lastGenLine++;
			addTo(mappingsSide, mappingsLine, lastGenLine + ": ");
		}
		if(typeof mapping.originalLine == "number") {
			if(lastOrgSource !== mapping.source && mapSources.length > 1) {
				addTo(mappingsSide, mappingsLine, "<b>[" + formatSource(mapping.source) + "]</b> ");
				lastOrgSource = mapping.source;
			}
			var source = mapSources.indexOf(mapping.source);
			addTo(mappingsSide, mappingsLine, span(mapping.generatedColumn + "->" + mapping.originalLine + ":" + mapping.originalColumn, {
				mapping: true,
				source: source,
				line: mapping.originalLine,
				column: mapping.originalColumn
			}));
		} else {
			addTo(mappingsSide, mappingsLine, span(mapping.generatedColumn, {
				mapping: true
			}));
		}
		addTo(mappingsSide, mappingsLine, "  ");
	});


	var originalLine = 1;
	var line = 1, column = 0, currentOutputLine = 1, targetOutputLine = -1, limited = false;
	var lastMapping = null;
	var currentSource = null;
	var exampleLines;
	var mappingsBySource = {};
	map.eachMapping(function(mapping) {
		if(typeof mapping.originalLine !== "number") return;
		if(mapping.generatedLine > MAX_LINES) return limited = true;
		if(!mappingsBySource[mapping.source]) mappingsBySource[mapping.source] = [];
		mappingsBySource[mapping.source].push(mapping);
	}, undefined, SourceMap.SourceMapConsumer.ORIGINAL_ORDER);
	Object.keys(mappingsBySource).map(function(source) {
		return [source, mappingsBySource[source][0].generatedLine];
	}).sort(function(a, b) {
		if(a[0] === "?") return 1;
		if(b[0] === "?") return -1;
		return a[1] - b[1];
	}).forEach(function(arr) {
		var source = arr[0];
		var mappings = mappingsBySource[source];

		if(currentSource) endFile();
		lastMapping = null;
		line = 1;
		column = 0;
		targetOutputLine = -1;
		if(mapSources.length > 1) {
			currentOutputLine++;
		}
		var startLine = mappings.map(function(mapping) {
			return mapping.generatedLine - mapping.originalLine + 1;
		}).sort(function(a, b) { return a - b });
		startLine = startLine[0];
		while(currentOutputLine < startLine) {
			originalLine++;
			currentOutputLine++;
		}
		if(mapSources.length > 1) {
			addTo(originalSide, originalLine, "<h4>[" + formatSource(source) + "]</h4>");
			originalLine++;
		}
		var exampleSource = sources[mapSources.indexOf(source)];
		if(!exampleSource) throw new Error("Source '" + source + "' missing");
		exampleLines = exampleSource.split("\n");
		currentSource = source;
		mappings.forEach(function(mapping, idx) {
			if(lastMapping) {
				var source = mapSources.indexOf(lastMapping.source);
				if(line < mapping.originalLine) {
					addTo(originalSide, originalLine, span(exampleLines.shift(), {
						original: true,
						source: source,
						line: lastMapping.originalLine,
						column: lastMapping.originalColumn
					}));
					originalLine++;
					line++; column = 0;
					currentOutputLine++;
					while(line < mapping.originalLine) {
						addTo(originalSide, originalLine, exampleLines.shift());
						originalLine++;
						line++; column = 0;
						currentOutputLine++;
					}
					startLine = [];
					for(var i = idx; i < mappings.length && mappings[i].originalLine <= mapping.originalLine + 1; i++) {
						startLine.push(mappings[i].generatedLine - mappings[i].originalLine + mapping.originalLine);
					}
					startLine.sort(function(a, b) { return a - b });
					startLine = startLine[0];
					while(typeof startLine !== "undefined" && currentOutputLine < startLine) {
						addTo(originalSide, originalLine, "~");
						originalLine++;
						currentOutputLine++;
					}
					if(column < mapping.originalColumn) {
						addTo(originalSide, originalLine, shiftColumns(mapping.originalColumn - column));
					}
				}
				if(mapping.originalColumn > column) {
					addTo(originalSide, originalLine, span(shiftColumns(mapping.originalColumn - column), {
						original: true,
						source: source,
						line: lastMapping.originalLine,
						column: lastMapping.originalColumn
					}));
				}
			} else {
				while(line < mapping.originalLine) {
					addTo(originalSide, originalLine, exampleLines.shift());
					originalLine++;
					line++; column = 0;
				}
				if(column < mapping.originalColumn) {
					addTo(originalSide, originalLine, shiftColumns(mapping.originalColumn - column));
				}
			}
			lastMapping = mapping;
		});
	});
	function endFile() {
		if(lastMapping) {
			var source = mapSources.indexOf(lastMapping.source);
			addTo(originalSide, originalLine, span(exampleLines.shift(), {
				original: true,
				source: source,
				line: lastMapping.originalLine,
				column: lastMapping.originalColumn
			}));
		}
		if(!limited) {
			exampleLines.forEach(function(line) {
				originalLine++;
				currentOutputLine++;
				addTo(originalSide, originalLine, line);
			});
		}
	}
	endFile();

	function shiftColumns(count) {
		var nextLine = exampleLines[0];
		exampleLines[0] = nextLine.substr(count);
		column += count;
		return nextLine.substr(0, count);
	}

	var length = Math.max(originalSide.length, generatedSide.length, mappingsSide.length);

	var tableRows = [];

	for(var i = 0; i < length; i++) {
		tableRows[i] = [
			originalSide[i] || "",
			generatedSide[i] || "",
			mappingsSide[i] || ""
		].map(function(cell) {
			return "<td>" + cell + "</td>";
		}).join("");
	}

	return "<!DOCTYPE html>\n<html>\n<style>" + CSS + "</style>\n<table><tbody>\n" + tableRows.map(function(row) {
		return "<tr>" + row + "</tr>\n";
	}).join("") + "</tbody></table>\n"
	+ '<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.2.1/jquery.min.js"/></script><script>' + SCRIPT + "</script></html>";


}

})();

(function ($hx_exports) { "use strict";
function $extend(from, fields) {
	function Inherit() {} Inherit.prototype = from; var proto = new Inherit();
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var Bundler = function(parser,sourceMap,extractor) {
	this.parser = parser;
	this.sourceMap = sourceMap;
	this.extractor = extractor;
};
Bundler.prototype = {
	generate: function(src,output,commonjs,debugSourceMap) {
		this.commonjs = commonjs;
		this.debugSourceMap = debugSourceMap;
		console.log("Emit " + output);
		var result = [];
		var buffer = this.emitBundle(src,this.extractor.main,true);
		result.push({ name : "Main", map : this.writeMap(output,buffer), source : this.write(output,buffer.src), debugMap : buffer.debugMap});
		var _g = 0;
		var _g1 = this.extractor.bundles;
		while(_g < _g1.length) {
			var bundle = _g1[_g];
			++_g;
			var bundleOutput = js_node_Path.join(js_node_Path.dirname(output),bundle.name + ".js");
			console.log("Emit " + bundleOutput);
			buffer = this.emitBundle(src,bundle,false);
			result.push({ name : bundle.name, map : this.writeMap(bundleOutput,buffer), source : this.write(bundleOutput,buffer.src), debugMap : buffer.debugMap});
		}
		return result;
	}
	,writeMap: function(output,buffer) {
		if(buffer.map == null) {
			return null;
		}
		return { path : "" + output + ".map", content : this.sourceMap.emitFile(output,buffer.map).toString()};
	}
	,write: function(output,buffer) {
		if(buffer == null) {
			return null;
		}
		return { path : output, content : buffer};
	}
	,hasChanged: function(output,buffer) {
		if(!js_node_Fs.statSync(output).isFile()) {
			return true;
		}
		var original = js_node_Fs.readFileSync(output).toString();
		return original != buffer;
	}
	,emitBundle: function(src,bundle,isMain) {
		var output = this.emitJS(src,bundle,isMain);
		var map = this.sourceMap.emitMappings(output.mapNodes,output.mapOffset);
		var debugMap = this.debugSourceMap ? this.emitDebugMap(output.buffer,bundle,map) : null;
		return { src : output.buffer, map : map, debugMap : debugMap};
	}
	,emitDebugMap: function(src,bundle,map) {
		var rawMap = JSON.parse(map.toString());
		var consumer = new sourcemap_SourceMapConsumer(rawMap);
		var _g = [];
		var _g1 = 0;
		var _g2 = rawMap.sources;
		while(_g1 < _g2.length) {
			var source = _g2[_g1];
			++_g1;
			var fileName = source.split("file:///").pop();
			if(Sys.systemName() != "Windows") {
				fileName = "/" + fileName;
			}
			_g.push(js_node_Fs.readFileSync(fileName).toString());
		}
		var sources = _g;
		return Bundler.generateHtml(consumer,src,sources);
	}
	,emitJS: function(src,bundle,isMain) {
		var mapOffset = 0;
		var exports = bundle.exports;
		var buffer = "";
		var body = this.parser.rootBody.slice();
		body.shift();
		if(isMain) {
			buffer += this.getBeforeBodySrc(src);
			mapOffset += this.getBeforeBodyOffset();
		} else {
			++mapOffset;
		}
		var run = isMain ? body.pop() : null;
		var inc = bundle.nodes;
		var incAll = isMain && bundle.nodes.length == 0;
		var mapNodes = [];
		var frag = isMain || bundle.isLib ? Bundler.FRAGMENTS.MAIN : Bundler.FRAGMENTS.CHILD;
		if(this.commonjs) {
			buffer += "/* eslint-disable */ \"use strict\"\n";
			++mapOffset;
			buffer += frag.EXPORTS;
			++mapOffset;
			buffer += frag.SHARED;
			++mapOffset;
		} else {
			buffer += "(function ($hx_exports, $global) { \"use-strict\";\n";
			++mapOffset;
			buffer += frag.SHARED;
			++mapOffset;
			buffer += "var require = (function(r){ return function require(m) { return r[m]; } })($s.__registry__);\n";
			++mapOffset;
		}
		if(bundle.shared.length > 0) {
			var tmp;
			if(isMain) {
				tmp = bundle.shared;
			} else {
				var _g = [];
				var _g1 = 0;
				var _g2 = bundle.shared;
				while(_g1 < _g2.length) {
					var node = _g2[_g1];
					++_g1;
					_g.push("" + node + " = $" + "s." + node);
				}
				tmp = _g;
			}
			buffer += "var " + tmp.join(", ") + ";\n";
			++mapOffset;
		}
		var _g3 = 0;
		while(_g3 < body.length) {
			var node1 = body[_g3];
			++_g3;
			if(!incAll && node1.__tag__ != null && inc.indexOf(node1.__tag__) < 0) {
				if(!isMain || node1.__tag__ != "__reserved__") {
					continue;
				}
			}
			mapNodes.push(node1);
			buffer += HxOverrides.substr(src,node1.start,node1.end - node1.start);
			buffer += "\n";
		}
		buffer += this.emitHot(inc);
		if(exports.length > 0) {
			var _g4 = 0;
			while(_g4 < exports.length) {
				var node2 = exports[_g4];
				++_g4;
				buffer += "$" + "s." + node2 + " = " + node2 + "; ";
			}
			buffer += "\n";
		}
		if(run != null) {
			buffer += HxOverrides.substr(src,run.start,run.end - run.start);
			buffer += "\n";
		}
		if(!this.commonjs) {
			buffer += "})(" + "typeof exports != \"undefined\" ? exports : typeof window != \"undefined\" ? window : typeof self != \"undefined\" ? self : this" + ", " + "typeof window != \"undefined\" ? window : typeof global != \"undefined\" ? global : typeof self != \"undefined\" ? self : this" + ");\n";
		}
		return { buffer : buffer, mapNodes : mapNodes, mapOffset : mapOffset};
	}
	,getBeforeBodyOffset: function() {
		return this.parser.rootExpr.loc.start.line;
	}
	,getBeforeBodySrc: function(src) {
		return HxOverrides.substr(src,0,this.parser.rootExpr.start);
	}
	,emitHot: function(inc) {
		var names = [];
		var _g = 0;
		var _g1 = Reflect.fields(this.parser.isHot);
		while(_g < _g1.length) {
			var name = _g1[_g];
			++_g;
			if(this.parser.isHot[name] && inc.indexOf(name) >= 0) {
				names.push(name);
			}
		}
		if(names.length == 0) {
			return "";
		}
		return "if ($" + "global.__REACT_HOT_LOADER__)\n" + ("  [" + names.join(",") + "].map(function(c) {\n") + "    __REACT_HOT_LOADER__.register(c,c.displayName,c.__fileName__);\n" + "  });\n";
	}
};
var EReg = function(r,opt) {
	this.r = new RegExp(r,opt.split("u").join(""));
};
EReg.prototype = {
	match: function(s) {
		if(this.r.global) {
			this.r.lastIndex = 0;
		}
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
};
var Extractor = function(parser) {
	this.bundles = [];
	this.parser = parser;
};
Extractor.prototype = {
	process: function(mainModule,modules,debugMode) {
		if(this.parser.typesCount == 0) {
			console.log("Warning: unable to process (no type metadata)");
			this.main = { isLib : false, name : "Main", nodes : [], exports : [], shared : []};
			return;
		}
		console.log("Bundling...");
		var g = this.parser.graph;
		var _g = 0;
		while(_g < modules.length) {
			var $module = modules[_g];
			++_g;
			this.unlink(g,$module);
		}
		var mainNodes = graphlib_Alg.preorder(g,mainModule);
		if(debugMode) {
			var _g1 = 0;
			var _g11 = Reflect.fields(this.parser.isEnum);
			while(_g1 < _g11.length) {
				var key = _g11[_g1];
				++_g1;
				mainNodes.push(key);
			}
		}
		this.bundles = modules.map($bind(this,this.processModule));
		var dupes = this.deduplicate(this.bundles,mainNodes,debugMode);
		mainNodes = this.addOnce(mainNodes,dupes.removed);
		var mainExports = dupes.shared;
		var mainShared = this.bundles.filter(function(bundle) {
			return !bundle.isLib;
		}).map(function(bundle1) {
			return bundle1.name;
		});
		var _g2 = 0;
		var _g12 = this.bundles;
		while(_g2 < _g12.length) {
			var bundle2 = _g12[_g2];
			++_g2;
			if(bundle2.isLib) {
				mainNodes = this.remove(bundle2.nodes,mainNodes);
				mainExports = this.remove(bundle2.nodes,mainExports);
				bundle2.exports = bundle2.nodes.slice();
			}
		}
		this.main = { isLib : false, name : "Main", nodes : mainNodes, exports : mainExports, shared : mainShared};
	}
	,processModule: function(name) {
		var g = this.parser.graph;
		if(name.indexOf("=") > 0) {
			var parts = name.split("=");
			var test = new EReg("^" + parts[1].split(",").join("|"),"");
			var ret = { isLib : true, name : parts[0], nodes : g.nodes().filter(function(n) {
				return test.match(n);
			}), exports : [], shared : []};
			return ret;
		} else {
			return { isLib : false, name : name, nodes : graphlib_Alg.preorder(g,name), exports : [name], shared : []};
		}
	}
	,deduplicate: function(bundles,mainNodes,debugMode) {
		console.log("Extract common chunks..." + (debugMode ? " (fast)" : ""));
		var map = new haxe_ds_StringMap();
		var _g = 0;
		while(_g < mainNodes.length) {
			var node = mainNodes[_g];
			++_g;
			if(__map_reserved[node] != null) {
				map.setReserved(node,true);
			} else {
				map.h[node] = true;
			}
		}
		var dupes = [];
		var _g1 = 0;
		while(_g1 < bundles.length) {
			var bundle = bundles[_g1];
			++_g1;
			var _g11 = 0;
			var _g2 = bundle.nodes;
			while(_g11 < _g2.length) {
				var node1 = _g2[_g11];
				++_g11;
				if(__map_reserved[node1] != null ? map.existsReserved(node1) : map.h.hasOwnProperty(node1)) {
					if(dupes.indexOf(node1) < 0) {
						dupes.push(node1);
					}
				} else if(bundle.isLib || !debugMode) {
					if(__map_reserved[node1] != null) {
						map.setReserved(node1,true);
					} else {
						map.h[node1] = true;
					}
				}
			}
		}
		var shared = [];
		var g = this.parser.graph;
		var _g3 = 0;
		while(_g3 < dupes.length) {
			var node2 = dupes[_g3];
			++_g3;
			var pre = g.predecessors(node2).filter(function(preNode) {
				return dupes.indexOf(preNode) < 0;
			});
			if(pre.length > 0) {
				shared.push(node2);
			}
		}
		var _g4 = 0;
		while(_g4 < bundles.length) {
			var bundle1 = [bundles[_g4]];
			++_g4;
			if(!bundle1[0].isLib) {
				var bundle2 = bundle1[0].nodes;
				var tmp = (function(bundle3) {
					return function(node3) {
						if(dupes.indexOf(node3) < 0) {
							return true;
						}
						if(shared.indexOf(node3) >= 0) {
							bundle3[0].shared.push(node3);
						}
						return false;
					};
				})(bundle1);
				bundle1[0].nodes = bundle2.filter(tmp);
			}
		}
		console.log("Moved " + dupes.length + " common chunks (" + shared.length + " shared)");
		return { removed : dupes, shared : shared};
	}
	,remove: function(source,target) {
		return source.filter(function(node) {
			return target.indexOf(node) < 0;
		});
	}
	,addOnce: function(source,target) {
		var temp = target.slice();
		var _g = 0;
		while(_g < source.length) {
			var node = source[_g];
			++_g;
			if(target.indexOf(node) < 0) {
				temp.push(node);
			}
		}
		return temp;
	}
	,unlink: function(g,name) {
		if(name.indexOf("=") > 0) {
			return;
		}
		var pred = g.predecessors(name);
		if(pred == null) {
			console.log("Cannot unlink " + name);
			return;
		}
		var _g = 0;
		while(_g < pred.length) {
			var p = pred[_g];
			++_g;
			g.removeEdge(p,name);
		}
	}
};
var HxOverrides = function() { };
HxOverrides.strDate = function(s) {
	var _g = s.length;
	switch(_g) {
	case 8:
		var k = s.split(":");
		var d = new Date();
		d["setTime"](0);
		d["setUTCHours"](k[0]);
		d["setUTCMinutes"](k[1]);
		d["setUTCSeconds"](k[2]);
		return d;
	case 10:
		var k1 = s.split("-");
		return new Date(k1[0],k1[1] - 1,k1[2],0,0,0);
	case 19:
		var k2 = s.split(" ");
		var y = k2[0].split("-");
		var t = k2[1].split(":");
		return new Date(y[0],y[1] - 1,y[2],t[0],t[1],t[2]);
	default:
		throw new js__$Boot_HaxeError("Invalid date format : " + s);
	}
};
HxOverrides.cca = function(s,index) {
	var x = s.charCodeAt(index);
	if(x != x) {
		return undefined;
	}
	return x;
};
HxOverrides.substr = function(s,pos,len) {
	if(len == null) {
		len = s.length;
	} else if(len < 0) {
		if(pos == 0) {
			len = s.length + len;
		} else {
			return "";
		}
	}
	return s.substr(pos,len);
};
var Main = function() { };
Main.run = $hx_exports["run"] = function(input,output,modules,debugMode,commonjs,debugSourceMap,dump) {
	var src = js_node_Fs.readFileSync(input).toString();
	var parser = new Parser(src);
	var sourceMap = new SourceMap(input,src);
	if(dump) {
		Main.dumpGraph(output,parser);
	}
	var extractor = new Extractor(parser);
	extractor.process(parser.mainModule,modules,debugMode);
	var bundler = new Bundler(parser,sourceMap,extractor);
	var dir = js_node_Path.dirname(output);
	return bundler.generate(src,output,commonjs,debugSourceMap);
};
Main.dumpGraph = function(output,parser) {
	var g = parser.graph;
	console.log("Dump graph: " + output + ".graph");
	var out = "";
	var _g = 0;
	var _g1 = g.nodes();
	while(_g < _g1.length) {
		var node = _g1[_g];
		++_g;
		if(node.charAt(0) != "$") {
			var toNode = g.inEdges(node).map(function(n) {
				return n.v.split("_").join(".");
			}).filter(function(l) {
				return l.charAt(0) != "$";
			});
			if(toNode.length == 0) {
				continue;
			}
			out += "+ " + node + " < " + toNode.join(", ") + "\n";
			var fromNode = g.outEdges(node).map(function(n1) {
				return n1.w.split("_").join(".");
			}).filter(function(l1) {
				return l1.charAt(0) != "$";
			});
			var _g2 = 0;
			while(_g2 < fromNode.length) {
				var dest = fromNode[_g2];
				++_g2;
				out += "  - " + dest + "\n";
			}
		}
	}
	js_node_Fs.writeFileSync(output + ".graph",out);
};
var Parser = function(src) {
	this.reservedTypes = { "String" : true, "Math" : true, "Array" : true, "Int" : true, "Float" : true, "Bool" : true, "Class" : true, "Date" : true, "Dynamic" : true, "Enum" : true, __map_reserved : true};
	this.mainModule = "Main";
	var t0 = new Date().getTime();
	this.processInput(src);
	var t1 = new Date().getTime();
	console.log("Parsed in: " + (t1 - t0) + "ms");
	this.buildGraph();
	var t2 = new Date().getTime();
	console.log("Graph processed in: " + (t2 - t1) + "ms");
};
Parser.prototype = {
	processInput: function(src) {
		var program = acorn_Acorn.parse(src,{ ecmaVersion : 5, locations : true, ranges : true});
		this.walkProgram(program);
	}
	,buildGraph: function() {
		var g = new graphlib_Graph({ directed : true, compound : true});
		var cpt = 0;
		var refs = 0;
		var _g = 0;
		var _g1 = Reflect.fields(this.types);
		while(_g < _g1.length) {
			var t = _g1[_g];
			++_g;
			++cpt;
			g.setNode(t,t);
		}
		var _g2 = 0;
		var _g11 = Reflect.fields(this.types);
		while(_g2 < _g11.length) {
			var t1 = _g11[_g2];
			++_g2;
			refs += this.walk(g,t1,this.types[t1]);
		}
		console.log("Stats: " + cpt + " types, " + refs + " references");
		this.typesCount = cpt;
		this.graph = g;
	}
	,walk: function(g,id,nodes) {
		var _gthis = this;
		var refs = 0;
		var visitors = { Identifier : function(node) {
			var name = node.name;
			if(name != id && Object.prototype.hasOwnProperty.call(_gthis.types,name)) {
				g.setEdge(id,name);
				refs += 1;
			}
		}};
		var _g = 0;
		while(_g < nodes.length) {
			var decl = nodes[_g];
			++_g;
			acorn_Walk.simple(decl,visitors);
		}
		return refs;
	}
	,walkProgram: function(program) {
		this.types = { };
		this.isHot = { };
		this.isEnum = { };
		this.isRequire = { };
		var body = this.getBodyNodes(program);
		this.rootExpr = body.pop();
		var _g = this.rootExpr.type;
		if(_g == "ExpressionStatement") {
			this.walkRootExpression(this.rootExpr.expression);
		} else {
			throw new js__$Boot_HaxeError("Expecting last node to be an ExpressionStatement");
		}
	}
	,walkRootExpression: function(expr) {
		var _g = expr.type;
		if(_g == "CallExpression") {
			this.walkRootFunction(expr.callee);
		} else {
			throw new js__$Boot_HaxeError("Expecting last node statement to be a function call");
		}
	}
	,walkRootFunction: function(callee) {
		var block = this.getBodyNodes(callee)[0];
		var _g = block.type;
		if(_g == "BlockStatement") {
			var body = this.getBodyNodes(block);
			this.walkDeclarations(body);
		} else {
			throw new js__$Boot_HaxeError("Expecting block of statements inside root function");
		}
	}
	,walkDeclarations: function(body) {
		this.rootBody = body;
		var _g = 0;
		while(_g < body.length) {
			var node = body[_g];
			++_g;
			var _g1 = node.type;
			switch(_g1) {
			case "ExpressionStatement":
				this.inspectExpression(node.expression,node);
				break;
			case "FunctionDeclaration":
				this.inspectFunction(node.id,node);
				break;
			case "IfStatement":
				if(node.consequent.type == "ExpressionStatement") {
					this.inspectExpression(node.consequent.expression,node);
				} else {
					this.inspectIfStatement(node.test,node);
				}
				break;
			case "VariableDeclaration":
				this.inspectDeclarations(node.declarations,node);
				break;
			default:
				console.log("WARNING: Unexpected " + node.type + ", Line " + node.loc.start.line);
			}
		}
	}
	,inspectIfStatement: function(test,def) {
		if(test.type == "BinaryExpression") {
			var path = this.getIdentifier(test.left);
			if(path.length > 1 && path[1] == "prototype") {
				this.tag(path[0],def);
			}
		}
	}
	,inspectFunction: function(id,def) {
		var path = this.getIdentifier(id);
		if(path.length > 0) {
			var name = path[0];
			if(name == "$extend" || name == "$bind" || name == "$iterator") {
				this.tag(name,def);
			}
		}
	}
	,inspectExpression: function(expression,def) {
		var _g = expression.type;
		switch(_g) {
		case "AssignmentExpression":
			var path = this.getIdentifier(expression.left);
			if(path.length > 0) {
				var name = path[0];
				switch(name) {
				case "$hxClasses":
					var moduleName = this.getIdentifier(expression.right);
					if(moduleName.length == 1) {
						this.tag(moduleName[0],def);
					}
					break;
				case "$hx_exports":
					break;
				default:
					if(Object.prototype.hasOwnProperty.call(this.types,name)) {
						if(path[1] == "displayName") {
							this.trySetHot(name);
						} else if(path[1] == "__fileName__") {
							this.trySetHot(name);
						}
					}
					this.tag(name,def);
				}
			}
			break;
		case "CallExpression":
			var path1 = this.getIdentifier(expression.callee.object);
			var prop = this.getIdentifier(expression.callee.property);
			if(prop.length > 0 && path1.length > 0 && Object.prototype.hasOwnProperty.call(this.types,path1[0])) {
				var name1 = path1[0];
				if(prop.length == 1 && prop[0] == "main") {
					this.mainModule = name1;
				}
				this.tag(name1,def);
			}
			break;
		default:
		}
	}
	,trySetHot: function(name) {
		if(Object.prototype.hasOwnProperty.call(this.isHot,name)) {
			this.isHot[name] = true;
		} else {
			this.isHot[name] = false;
		}
	}
	,inspectDeclarations: function(declarations,def) {
		var _g = 0;
		while(_g < declarations.length) {
			var decl = declarations[_g];
			++_g;
			if(decl.id != null) {
				var name = decl.id.name;
				if(decl.init != null) {
					var init = decl.init;
					var _g1 = init.type;
					switch(_g1) {
					case "AssignmentExpression":
						var right = init.right;
						if(right.type == "FunctionExpression") {
							this.tag(name,def);
						} else if(right.type == "ObjectExpression") {
							if(this.isEnumDecl(right)) {
								this.isEnum[name] = true;
							}
							this.tag(name,def);
						}
						break;
					case "CallExpression":
						if(this.isRequireDecl(init.callee)) {
							this.required(name,def);
						}
						break;
					case "FunctionExpression":
						this.tag(name,def);
						break;
					case "Identifier":
						if(name.charAt(0) != "$") {
							this.tag(name,def);
						}
						break;
					case "LogicalExpression":
						if(name.indexOf("Array") >= 0) {
							this.tag(name,def);
						}
						break;
					case "MemberExpression":
						if(init.object.type == "CallExpression" && this.isRequireDecl(init.object.callee)) {
							this.required(name,def);
						}
						break;
					case "ObjectExpression":
						if(this.isEnumDecl(init)) {
							this.isEnum[name] = true;
						}
						this.tag(name,def);
						break;
					default:
					}
				}
			}
		}
	}
	,required: function(name,def) {
		this.isRequire[name] = true;
		this.tag(name,def);
	}
	,tag: function(name,def) {
		if(!Object.prototype.hasOwnProperty.call(this.types,name)) {
			if(this.reservedTypes[name]) {
				if(name != "__map_reserved") {
					def.__tag__ = "__reserved__";
				}
				return;
			}
			this.types[name] = [def];
		} else {
			this.types[name].push(def);
		}
		def.__tag__ = name;
	}
	,isReserved: function(name) {
		return this.reservedTypes[name];
	}
	,isEnumDecl: function(node) {
		var props = node.properties;
		if(node.type == "ObjectExpression" && props != null && props.length > 0) {
			return this.getIdentifier(props[0].key)[0] == "__ename__";
		} else {
			return false;
		}
	}
	,isRequireDecl: function(node) {
		if(node != null && node.type == "Identifier") {
			return node.name == "require";
		} else {
			return false;
		}
	}
	,getBodyNodes: function(node) {
		if((node.body instanceof Array) && node.body.__enum__ == null) {
			return node.body;
		} else {
			return [node.body];
		}
	}
	,getIdentifier: function(left) {
		var _g = left.type;
		switch(_g) {
		case "Identifier":
			return [left.name];
		case "Literal":
			return [left.raw];
		case "MemberExpression":
			return this.getIdentifier(left.object).concat(this.getIdentifier(left.property));
		default:
			return [];
		}
	}
};
var Reflect = function() { };
Reflect.fields = function(o) {
	var a = [];
	if(o != null) {
		var hasOwnProperty = Object.prototype.hasOwnProperty;
		for( var f in o ) {
		if(f != "__id__" && f != "hx__closures__" && hasOwnProperty.call(o,f)) {
			a.push(f);
		}
		}
	}
	return a;
};
var SourceMap = function(input,src) {
	var p = src.lastIndexOf("//# sourceMappingURL=");
	if(p < 0) {
		return;
	}
	this.fileName = StringTools.trim(HxOverrides.substr(src,p + "//# sourceMappingURL=".length,null));
	this.fileName = js_node_Path.join(js_node_Path.dirname(input),this.fileName);
	var raw = JSON.parse(js_node_Fs.readFileSync(this.fileName).toString());
	this.source = new sourcemap_SourceMapConsumer(raw);
};
SourceMap.prototype = {
	emitMappings: function(nodes,offset) {
		if(nodes.length == 0 || this.source == null) {
			return null;
		}
		var inc = [];
		var line = offset;
		var _g = 0;
		while(_g < nodes.length) {
			var node = nodes[_g];
			++_g;
			var _g2 = node.loc.start.line;
			var _g1 = node.loc.end.line + 1;
			while(_g2 < _g1) {
				var i = _g2++;
				inc[i] = line++;
			}
		}
		var output = new sourcemap_SourceMapGenerator();
		var sourceFiles = { };
		try {
			this.source.eachMapping(function(mapping) {
				if(!isNaN(inc[mapping.generatedLine])) {
					sourceFiles[mapping.source] = true;
					var mapLine = inc[mapping.generatedLine];
					var column = mapping.originalColumn >= 0 ? mapping.originalColumn : 0;
					output.addMapping({ source : mapping.source, original : { line : mapping.originalLine, column : column}, generated : { line : mapLine, column : mapping.generatedColumn}});
				}
			});
			var _g3 = 0;
			var _g11 = Reflect.fields(sourceFiles);
			while(_g3 < _g11.length) {
				var sourceName = _g11[_g3];
				++_g3;
				var src = this.source.sourceContentFor(sourceName,true);
				if(src != null) {
					output.setSourceContent(sourceName,src);
				}
			}
			return output;
		} catch( err ) {
			console.log("Invalid source-map");
		}
		return output;
	}
	,emitFile: function(output,map) {
		if(map == null) {
			return null;
		}
		map.file = js_node_Path.basename(output);
		return map;
	}
};
var StringTools = function() { };
StringTools.isSpace = function(s,pos) {
	var c = HxOverrides.cca(s,pos);
	if(!(c > 8 && c < 14)) {
		return c == 32;
	} else {
		return true;
	}
};
StringTools.ltrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,r)) ++r;
	if(r > 0) {
		return HxOverrides.substr(s,r,l - r);
	} else {
		return s;
	}
};
StringTools.rtrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,l - r - 1)) ++r;
	if(r > 0) {
		return HxOverrides.substr(s,0,l - r);
	} else {
		return s;
	}
};
StringTools.trim = function(s) {
	return StringTools.ltrim(StringTools.rtrim(s));
};
var Sys = function() { };
Sys.systemName = function() {
	var _g = process.platform;
	switch(_g) {
	case "darwin":
		return "Mac";
	case "freebsd":
		return "BSD";
	case "linux":
		return "Linux";
	case "win32":
		return "Windows";
	default:
		var other = _g;
		return other;
	}
};
var acorn_Acorn = require("acorn");
var acorn_Walk = require("acorn/dist/walk");
var graphlib_Graph = require("graphlib").Graph;
var graphlib_Alg = require("graphlib/lib/alg");
var haxe_IMap = function() { };
var haxe_ds_StringMap = function() {
	this.h = { };
};
haxe_ds_StringMap.__interfaces__ = [haxe_IMap];
haxe_ds_StringMap.prototype = {
	setReserved: function(key,value) {
		if(this.rh == null) {
			this.rh = { };
		}
		this.rh["$" + key] = value;
	}
	,existsReserved: function(key) {
		if(this.rh == null) {
			return false;
		}
		return this.rh.hasOwnProperty("$" + key);
	}
};
var haxe_io_Bytes = function() { };
var js__$Boot_HaxeError = function(val) {
	Error.call(this);
	this.val = val;
	this.message = String(val);
	if(Error.captureStackTrace) {
		Error.captureStackTrace(this,js__$Boot_HaxeError);
	}
};
js__$Boot_HaxeError.wrap = function(val) {
	if((val instanceof Error)) {
		return val;
	} else {
		return new js__$Boot_HaxeError(val);
	}
};
js__$Boot_HaxeError.__super__ = Error;
js__$Boot_HaxeError.prototype = $extend(Error.prototype,{
});
var js_node_Fs = require("fs");
var js_node_Path = require("path");
var js_node_buffer_Buffer = require("buffer").Buffer;
var sourcemap_SourceMapConsumer = require("source-map").SourceMapConsumer;
var sourcemap_SourceMapGenerator = require("source-map").SourceMapGenerator;
var $_, $fid = 0;
function $bind(o,m) { if( m == null ) return null; if( m.__id__ == null ) m.__id__ = $fid++; var f; if( o.hx__closures__ == null ) o.hx__closures__ = {}; else f = o.hx__closures__[m.__id__]; if( f == null ) { f = function(){ return f.method.apply(f.scope, arguments); }; f.scope = o; f.method = m; o.hx__closures__[m.__id__] = f; } return f; }
var __map_reserved = {}
Bundler.REQUIRE = "var require = (function(r){ return function require(m) { return r[m]; } })($s.__registry__);\n";
Bundler.SCOPE = "typeof exports != \"undefined\" ? exports : typeof window != \"undefined\" ? window : typeof self != \"undefined\" ? self : this";
Bundler.GLOBAL = "typeof window != \"undefined\" ? window : typeof global != \"undefined\" ? global : typeof self != \"undefined\" ? self : this";
Bundler.FUNCTION_START = "(function ($hx_exports, $global) { \"use-strict\";\n";
Bundler.FUNCTION_END = "})(" + "typeof exports != \"undefined\" ? exports : typeof window != \"undefined\" ? window : typeof self != \"undefined\" ? self : this" + ", " + "typeof window != \"undefined\" ? window : typeof global != \"undefined\" ? global : typeof self != \"undefined\" ? self : this" + ");\n";
Bundler.WP_START = "/* eslint-disable */ \"use strict\"\n";
Bundler.FRAGMENTS = { MAIN : { EXPORTS : "var $hx_exports = exports, $global = global;\n", SHARED : "var $s = $global.$hx_scope = $global.$hx_scope || {};\n"}, CHILD : { EXPORTS : "var $hx_exports = exports, $global = global;\n", SHARED : "var $s = $global.$hx_scope;\n"}};
Bundler.generateHtml = global.generateHtml;
SourceMap.SRC_REF = "//# sourceMappingURL=";
})(typeof exports != "undefined" ? exports : typeof window != "undefined" ? window : typeof self != "undefined" ? self : this);
