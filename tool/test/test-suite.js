"use strict";

const exec = require('child_process').exec;
const fs = require('fs');

try { fs.mkdirSync('tool/test/bin'); } catch (_) { }

const testClasses = ['Test1', 'Test2', 'Test3', 'Test4', 'Test5', 'Test6', 'Test7', 'Test8', 'Test9'];
const useLib = { Test4:true, Test5:true };

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
}];

function runInterop() {
	if (!suitesInterop.length) {
		return;
	}
	const className = 'TestInterop';
	const suite = suitesInterop.shift();
	const name = `${suite.name}-${className.toLowerCase()}`;
	console.log(`---------[${name}]---------`);
	execTest(className, name, suite.params, false, err => {
		if (err) return;
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
	runAllTests(suite.name, suite.params, suite.isNode, runSuites);
}

function runAllTests(suite, params, isNode, callback) {
	const cases = [].concat(testClasses);

	function runTest(err) {
		if (err || !cases.length) {
			callback();
			return;
		}
		const className = cases.shift();
		const name = `${suite}-${className.toLowerCase()}`;
		console.log(`---------[${name}]---------`);
		execTest(className, name, params, isNode, runTest);
	}
	runTest();
}

function execTest(className, name, params, isNode, callback) {
	const folder = `tool/test/bin/${name}`;
	if (useLib[className]) params += ' -D uselib';
	var cmd = `haxe tool/test/test-common.hxml -main ${className} -js ${folder}/index.js ${params}`;
	//console.log(cmd);
	exec(cmd, (err, stdout, stderr) => {
		if (err) {
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
	const valid = `tool/test/expect/${name}.json`;
	exec(`node tool/test/validate.js ${result} ${valid}`, (err, stdout, stderr) => {
		if (err) {
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

// run normal suites then advanced interop cases
runSuites();
