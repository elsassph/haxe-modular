#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const hooks = require('./hooks');

const args = [].concat(process.argv);
const debugMode = remove(args, '-debug');
const webpackMode = remove(args,  '-webpack');
const nodejsMode = remove(args, '-nodejs');
const debugSourceMap = remove(args,  '-debugmap');
const dump = remove(args, '-dump');

if (args.length < 3)
	return printUsage();

if (debugMode || webpackMode) {
	console.log('Options:');
	if (debugMode) console.log('- generate sourcemaps');
	if (webpackMode) console.log('- generate webpack-compatible source');
}

const t0 = new Date().getTime();
const input = args[2];
const output = args[3];
const modules = args.slice(4);

const split = require('../tool/bin/split');
const cjsMode = webpackMode || nodejsMode;
const graphHook = hooks.getGraphHooks();
const result = split.run(input, output, modules, debugMode, cjsMode, debugSourceMap, dump, graphHook);
for (file of result) {
	if (!file || !file.source) continue;
	if (file.map) {
		writeIfChanged(file.map.path, JSON.stringify(file.map.content));
	}
	const content = file.map
		? `${file.source.content}\n//# sourceMappingURL=${path.basename(file.map.path)}`
		: file.source.content;
	writeIfChanged(file.source.path, content);

	if (file.debugMap) {
		writeIfChanged(file.source.path + '.map.html', file.debugMap);
	}
}

const t1 = new Date().getTime();
console.log(`Total process: ${t1 - t0}ms`);


/* TOOLS */

function remove(a, v) {
	const i = a.indexOf(v);
	if (i < 0) return false;
	a.splice(i, 1);
	return true;
}

function hasChanged(output, content) {
	if (!fs.existsSync(output)) return true;
	var original = String(fs.readFileSync(output));
	return original != content;
}

function writeIfChanged(output, content) {
	if (hasChanged(output, content)) {
		console.log('Write ' + output);
		try { fs.mkdirSync(path.dirname(output)); } catch (_) { }
		fs.writeFileSync(output, content);
	}
}

function printUsage() {
	console.log(`
Haxe-JS code splitting, usage:
  haxe-split [-debug] [-webpack] <input.js> <output.js> [<module-1> ... <module-n>]

Arguments:
  -debug   : generate source maps
  -webpack : generate webpack-compatible source
  -nodejs  : generate nodejs-compatible source
  input.js : path to input JS source
  output.js: path to output JS source
  module-i : qualified Haxe module name to split
`);
}
