const fs = require('fs');
const path = require('path');

/**
 * Look in `package.json` for `config.haxe-split-hook` file(s)
 * and return ready-to-call hook functions to process the graph
 */
function getGraphHooks() {
	const hookFiles = readHookConfig();
	return hookFiles ? hookFiles.map(loadHandler) : null;
}

function loadHandler(fileName) {
	const filePath = path.normalize(fileName);
	const absPath = path.resolve(filePath);

	if (!fs.existsSync(filePath)) {
		console.error(`[haxe-split] Error: '${filePath}' hook does not exist`);
		return null;
	}

	const src = fs.readFileSync(filePath);
	const module = {
		exports: {}
	};
	const evaluator = new Function('module', 'exports', 'global', 'require', '__dirname', '__filename', src);
	evaluator(module, module.exports, global, require, path.dirname(absPath), absPath);

	const handler = module.exports;
	if (!handler || (typeof handler !== 'function')) {
		console.error(`[haxe-split] Error: '${filePath}' hook does not export a function`);
		return null;
	}
	return handler;
}

function readHookConfig() {
	if (!fs.existsSync('package.json')) return null;

	const pkg = JSON.parse(fs.readFileSync('package.json'));
	const config = pkg.config;
	if (!config) return null;
	let hookFiles = config['haxe-split-hook'];
	if (!hookFiles) return null;
	if (typeof hookFiles === 'string') hookFiles = [hookFiles];
	return hookFiles;
}

module.exports.getGraphHooks = getGraphHooks;
