const fs = require('fs');
const run = require('./run');

//
// Add in your project's `khafile.js`, before `resolve(project)`:
//
//     require('haxe-modular/bin/kha').register(platform, project, callbacks);
//

module.exports.register = (platform, project, callbacks) => {

	project.addLibrary('modular');

	if (platform != 'html5') { // 'debug-html5' is an electron target at the moment
		project.addDefine('modular_stub');
		return;
	}

	project.addDefine('modular_noprocess');

	callbacks.postHaxeCompilation = () => {
		const args = JSON.parse(fs.readFileSync('build/.temp/split-args.json'));

		const debugMode = remove(args, '-debug');
		const debugSourceMap = remove(args,  '-debugmap');
		const dump = remove(args, '-dump');
		const cjsMode = false;

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
