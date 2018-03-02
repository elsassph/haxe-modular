const fs = require('fs');
const path = require('path');
const run = require('./run');

//
// Add in your project's `khafile.js`, before `resolve(project)`:
//
//     require('haxe-modular/bin/kha').register(project, callbacks);
//

module.exports.register = (project, callbacks) => {

	project.addLibrary('modular');
	project.addDefine('modular_noprocess');

	callbacks.postHaxeCompilation = () => {
		const args = JSON.parse(fs.readFileSync('build/.temp/split-args.json'));

		const debugMode = remove(args, '-debug');
		const debugSourceMap = remove(args,  '-debugmap');
		const dump = remove(args, '-dump');
		const cjsMode = true;

		const input = args[0];
		const output = args[1];
		const modules = args.slice(2);

		run(input, output, modules, debugMode, cjsMode, debugSourceMap, dump);
	}
}

function remove(a, v) {
	const i = a.indexOf(v);
	if (i < 0) return false;
	a.splice(i, 1);
	return true;
}
