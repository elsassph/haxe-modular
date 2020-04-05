"use strict";

const exec = require('child_process').exec;
const fs = require('fs');
const t0 = new Date().getTime();

try { fs.mkdirSync('tool/test/bin'); } catch (_) { }

const testClasses = [
	'Test1', 'Test2', 'Test3', 'Test4', 'Test5', 'Test6', 'Test7', 'Test8',
	'Test9', 'Test10', 'Test11', 'Test12', 'Test13', 'Test14', 'Test15'
];
const useLib = { Test4:true, Test5:true, Test12:true };

const { only, es6 } = getOnly();

const suites = [{
	name: 'node-debug',
	params: '-debug -D nodejs',
	isNode: true
}, {
	name: 'node-release',
	params: '-D nodejs',
	isNode: true
}, {
	name: 'web-debug',
	params: '-debug',
	isNode: false
}, {
	name: 'web-release',
	params: '',
	isNode: false
}];

const suitesInterop = [{
	name: 'web-debug',
	params: '-debug tool/test/test-interop.hxml',
	isNode: false
}, {
	name: 'web-release',
	params: 'tool/test/test-interop.hxml',
	isNode: false
},{
	name: 'web-debug-closure',
	params: '-debug tool/test/test-interop.hxml -lib closure -D closure_create_source_map',
	isNode: false
}, {
	name: 'web-release-closure',
	params: 'tool/test/test-interop.hxml -lib closure',
	isNode: false
},{
	name: 'web-debug-uglify',
	params: '-debug tool/test/test-interop.hxml -lib uglifyjs',
	isNode: false
}, {
	name: 'web-release-uglify',
	params: 'tool/test/test-interop.hxml -lib uglifyjs',
	isNode: false
}];

var hasFailedCase = 0;
var haxeVersion = '3';

function getOnly() {
	const args = [].concat(process.argv);
	if (args.length <= 2) return {};
	let only = args.slice(2);
	let es6 = false;
	if (only[0] === 'es6') {
		es6 = true;
		only.shift();
	}
	if (only.length === 0) only = null;
	return { only, es6 };
}

function exitWithResult() {
	// report case failure
	if (hasFailedCase) {
		console.log('One or more test case has failed:', hasFailedCase);
		process.exit(hasFailedCase);
	}
	console.log('Completed in', ((new Date().getTime() - t0) / 1000).toFixed(1) + 's');
}

function runInterop() {
	const className = 'TestInterop';
	if (!suitesInterop.length || (only && only[1] && only[1] !== className)) {
		exitWithResult();
		return;
	}
	const suite = suitesInterop.shift();
	const name = `${suite.name}-${className.toLowerCase()}`;
	if (only && only[0] !== suite.name) {
		runInterop();
		return;
	}
	console.log(`---------[${name}]---------`);
	execTest(className, name, suite.params, false, err => {
		if (err) {
			hasFailedCase = 4;
			runInterop();
			return;
		}
		const index = `tool/test/bin/${name}/index.html`;
		fs.writeFileSync(index, `<!DOCTYPE html><body><script src=index.js></script></body>`);
		runInterop();
	});
}

function runSuites() {
	if (!suites.length) {
		runInterop();
		return;
	}
	const suite = suites.shift();
	if (only && only[0] !== suite.name) {
		runSuites();
		return;
	}
	runAllTests(suite.name, suite.params, suite.isNode, runSuites);
}

function runAllTests(suite, params, isNode, callback) {
	const cases = [].concat(testClasses);

	function runTest(err) {
		if (err || !cases.length) {
			if (err) console.log(err);
			callback();
			return;
		}
		const className = cases.shift();
		if (only && only[1] && only[1] !== className) {
			runTest();
			return;
		}
		const name = `${suite}-${className.toLowerCase()}`;
		console.log(`---------[${name}]---------`);
		execTest(className, name, params, isNode, runTest);
	}
	runTest();
}

function execTest(className, name, params, isNode, callback) {
	const folder = `tool/test/bin/${name}`;
	if (useLib[className]) params += ' -D uselib';
	if (es6) params += ' -D js-es=6';
	var cmd = `haxe tool/test/test-common.hxml -main ${className} -js ${folder}/index.js ${params}`;
	//console.log(cmd);
	exec(cmd, (err, stdout, stderr) => {
		if (err) {
			hasFailedCase = 1;
			console.log(stderr);
			callback(err);
		} else {
			console.log(stdout);
			runValidation(name, isNode, callback);
		}
	});
}

function runValidation(name, isNode, callback) {
	const result = `tool/test/bin/${name}/index.js.json`;
	const valid = `tool/test/expect/haxe_${haxeVersion}/${name}.json`;
	exec(`node tool/test/validate.js ${result} ${valid}`, (err, stdout, stderr) => {
		if (err) {
			hasFailedCase = 2;
			console.log(stdout);
			callback(err);
		} else {
			console.log(stdout);
			if (isNode) runOutput(name, callback);
			else callback();
		}
	});
}

function runOutput(name, callback) {
	const output = `tool/test/bin/${name}/index.js`;
	console.log(`[Run] ${output}`);
	exec(`node ${output}`, (err, stdout, stderr) => {
		if (err) {
			hasFailedCase = 3;
			console.log(stderr);
			console.log('FAILED!');
			callback(err);
		} else {
			console.log('PASSED!');
			//console.log(stdout);
			callback();
		}
	});
}

function detectHaxe(callback) {
	exec(`haxe -version`, (err, stdout, stderr) => {
		if (err) {
			console.log(stderr);
			console.log('FATAL: Haxe binary missing');
			process.exit(-1);
		} else {
			const out = ('' + stdout + stderr).trim();
			const v = parseInt(out);
			console.log(`Running tests against Haxe version ${out} ->`, v, es6 ? '(ES6)' : '');
			if (v !== 3 && v !== 4) {
				console.log('FATAL: Haxe version unsupported');
				process.exit(-2);
			}
			if (v === 3 && es6) {
				console.log('ES6 mode not supported by Haxe 3 - ignoring');
				process.exit(0);
			}
			haxeVersion = `${v}${es6 ? '_es6' : ''}`;
			try { fs.mkdirSync(`tool/test/expect/haxe_${haxeVersion}`); } catch (_) { }
			callback();
		}
	});
}

detectHaxe(() => {
	// run normal suites then advanced interop cases
	runSuites();
});
