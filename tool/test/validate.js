"use strict";

const fs = require('fs');

const args = [].concat(process.argv);
const result = args[2];
const valid = args[3];

const resultRaw = String(fs.readFileSync(result));

// if valid is missing (or we want to update), save result
if (process.env.UPDATE_EXPECT === 'true' || !fs.existsSync(valid)) {
	console.log('[Update]', valid, 'from', result);
	fs.writeFileSync(valid, resultRaw);
}
// compare results
else {
	const validRaw = String(fs.readFileSync(valid));

	console.log('[Validate]', result, 'from', valid);

	// it is necessary to remove dependence on sequence of modules, so we sort them by name
	function sort(s) {
		const jsonData = JSON.parse(s);
		jsonData.sort(function(n1, n2) { return n1.name == n2.name ? 0 : n1.name < n2.name ? -1 : 1; });
		return JSON.stringify(jsonData);
	}

	if (sort(resultRaw) != sort(validRaw)) {
		console.log('FAILED!');
		// print diff
		const diff = require('json-diff/lib/cli');
		diff([valid, result]);
		process.exit(1);
	}

	console.log('PASSED!');
}
