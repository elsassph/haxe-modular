#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const run = require('./run');

/* ARGUMENTS */

const args = [].concat(process.argv);
const debugMode = remove(args, '-debug');
const webpackMode = remove(args,  '-webpack');
const nodejsMode = remove(args, '-nodejs');
const debugSourceMap = remove(args,  '-debugmap');
const dump = remove(args, '-dump');
const cjsMode = webpackMode || nodejsMode;

if (args.length < 3)
	return printUsage();

if (debugMode || webpackMode) {
	console.log('Options:');
	if (debugMode) console.log('- generate sourcemaps');
	if (webpackMode) console.log('- generate webpack-compatible source');
}

const input = args[2];
const output = args[3];
const modules = args.slice(4);

/* PROCESS */

try { fs.mkdirSync(path.dirname(output)); } catch (_) { }

run(input, output, modules, debugMode, cjsMode, debugSourceMap, dump);

/* UTIL */

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

function remove(a, v) {
	const i = a.indexOf(v);
	if (i < 0) return false;
	a.splice(i, 1);
	return true;
}
