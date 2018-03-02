const fs = require('fs');
const path = require('path');
const hooks = require('./hooks');
const split = require('../tool/bin/split');

module.exports = function(input, output, modules, debugMode, cjsMode, debugSourceMap, dump) {
	const t0 = new Date().getTime();
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
}

/* UTIL */

function hasChanged(output, content) {
	if (!fs.existsSync(output)) return true;
	var original = String(fs.readFileSync(output));
	return original != content;
}

function writeIfChanged(output, content) {
	if (hasChanged(output, content)) {
		console.log('Write ' + output);
		fs.writeFileSync(output, content);
	}
}
