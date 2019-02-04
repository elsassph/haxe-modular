"use strict";

const fs = require('fs');

const args = [].concat(process.argv);
const result = args[2];
const valid = args[3];

const resultRaw = String(fs.readFileSync(result));

// if valid is missing, save result
if (!fs.existsSync(valid)) {
	console.log('[Update]', valid, 'from', result);
	fs.writeFileSync(valid, resultRaw);
}
// compare results
else {
	const validRaw = String(fs.readFileSync(valid));

	console.log('[Validate]', result, 'from', valid);

	if (resultRaw != validRaw) {
		console.log('FAILED!');
		// print diff
		const diff = require('json-diff/lib/cli');
		diff([valid, result]);
		process.exit(1);
	}

	console.log('PASSED!');
}
