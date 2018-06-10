package acorn;

import acorn.Acorn;

typedef CherowOptions = {
	?module: Bool, // Enable module syntax
	?loc: Bool, // Attach line/column location information to each node
	?ranges: Bool, // Append start and end offsets to each node
	?impliedStrict: Bool, // Enable strict mode initial enforcement
	?next: Bool, // Enable stage 3 support (ESNext)
	?tolerant: Bool, // Create a top-level error array containing all "skipped" errors
	?source: Bool, // Set to true to record the source file in every node's loc object when the loc option is set.
	?raw: Bool, // Attach raw property to each literal node
	?rawIdentifier: Bool, // Attach raw property to each identifier node
}

@:jsRequire('cherow')
extern class Cherow {

	/**
	 * is used to parse a JavaScript program. The input parameter is a string, options can
	 * be undefined or an object setting some of the options listed below. The return value
	 * will be an abstract syntax tree object as specified by the ESTree spec.
	 */
	static public function parse(input:String, options:CherowOptions):AstNode;
}
