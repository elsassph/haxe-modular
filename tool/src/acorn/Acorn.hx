package acorn;

@:jsRequire('acorn')
extern class Acorn
{
	static public var version:String;
	
	/**
	 * holds an object mapping names to the token type objects that end up in the type
	 * properties of tokens.
	 */
	static public var tokTypes:Dynamic;
	
	/**
	 * is used to parse a JavaScript program. The input parameter is a string, options can 
	 * be undefined or an object setting some of the options listed below. The return value
	 * will be an abstract syntax tree object as specified by the ESTree spec.
	 */
	static public function parse(input:String, options:AcornOptions):AstNode;
	
	/**
	 * will parse a single expression in a string, and return its AST. 
	 * It will not complain if there is more of the string left after the expression.
	 */
	static public function parseExpressionAt(input:String, offset:Int, options:AcornOptions):AstNode;
	
	/**
	 * can be used to get a {line, column} object for a given program string and 
	 * character offset.
	 */
	static public function getLineInfo(input:String, offset:Int):{line:Int, column:Int};
	
	/**
	 * returns an object with a getToken method that can be called repeatedly to get the 
	 * next token, a {start, end, type, value} object (with added loc property when the 
	 * locations option is enabled and range property when the ranges option is enabled). 
	 * When the token's type is tokTypes.eof, you should stop calling the method, since 
	 * it will keep returning that same token forever.
	 */
	static public function tokenizer(input:String, options:AcornOptions):Tokenizer;
}

typedef AstPosition = {
	line: Int,
	column: Int
}

typedef AstSourceLocation = {
	source: String,
	start: AstPosition,
	end: AstPosition
}

typedef AstNode = {
	__tag__: String,
	type: String,
	loc: AstSourceLocation,
	source: String,
	start: Int,
	end: Int,
	range: Array<Int>,
	body: haxe.extern.EitherType<AstNode, Array<AstNode>>,
	// ExpressionStatement
	expression: AstNode, 
	// CallExpression
	callee: AstNode,
	arguments: Array<AstNode>,
	// FunctionExpression
	params: Array<AstNode>,
	// Identifier
	name: String,
	// Literal
	value: String,
	raw: String,
	// ConditionalExpression/IfStatement
	test: AstNode,
	consequent: AstNode,
	alternate: AstNode,
	// VariableDeclaration
	declarations: Array<AstNode>,
	// VariableDeclarator
	id: AstNode,
	init: AstNode,
	// AssignmentExpression
	left: AstNode,
	right: AstNode,
	// MemberExpression
	object: AstNode,
	property: AstNode,
	computer: Bool,
	// ObjectExpression
	properties: Array<AstNode>,
	// Property
	key: AstNode
}

typedef Tokenizer = {
	getToken:Void -> {start:Int, end:Int, type:String, value:String, loc:Dynamic }
}

typedef AcornOptions = {
	/**
	 * Indicates the ECMAScript version to parse. Must be either 3, 5, 6 (2015), 7 (2016), 
	 * or 8 (2017). This influences support for strict mode, the set of reserved words, 
	 * and support for new syntax features. Default is 7.
	 */
	@:optional var ecmaVersion:Int;
	/**
	 * Indicate the mode the code should be parsed in. Can be either "script" or "module".
	 * This influences global strict mode and parsing of import and export declarations.
	 */
	@:optional var sourceType:String;
	/**
	 * If given a callback, that callback will be called whenever a missing semicolon is 
	 * inserted by the parser. The callback will be given the character offset of the 
	 * point where the semicolon is inserted as argument, and if locations is on, also 
	 * a {line, column} object representing this position.
	 */
	@:optional var onInsertedSemicolon:Dynamic;
	/**
	 * Like onInsertedSemicolon, but for trailing commas
	 */
	@:optional var onTrailingComma:Dynamic;
	/**
	 * If false, using a reserved word will generate an error. Defaults to true for 
	 * ecmaVersion 3, false for higher versions. When given the value "never", reserved 
	 * words and keywords can also not be used as property names (as in Internet Explorer's 
	 * old parser).
	 */
	@:optional var allowReserved:Bool;
	/**
	 * By default, a return statement at the top level raises an error. Set this to true to 
	 * accept such code.
	 */
	@:optional var allowReturnOutsideFunction:Bool;
	/**
	 * By default, import and export declarations can only appear at a program's top level. 
	 * Setting this option to true allows them anywhere where a statement is allowed.
	 */
	@:optional var allowImportExportEverywhere:Bool;
	/**
	 * When this is enabled (off by default), if the code starts with the characters #! (as in 
	 * a shellscript), the first line will be treated as a comment.
	 */
	@:optional var allowHashBang:Bool;
	/**
	 * When true, each node has a loc object attached with start and end subobjects, each of 
	 * which contains the one-based line and zero-based column numbers in {line, column} form. 
	 * Default is false.
	 */
	@:optional var locations:Bool;
	/**
	 * If a function is passed for this option, each found token will be passed in same format 
	 * as tokens returned from tokenizer().getToken().
	 * If array is passed, each found token is pushed to it.
	 */
	@:optional var onToken:Dynamic;
	/**
	 * If a function is passed for this option, whenever a comment is encountered the function 
	 * will be called with the following parameters: (block, text, start, end, line, column)
	 */
	@:optional var onComment:Dynamic;
	/**
	 * Nodes have their start and end characters offsets recorded in start and end properties 
	 * (directly on the node, rather than the loc object, which holds line/column data. To 
	 * also add a semi-standardized range property holding a [start, end] array with the same 
	 * numbers, set the ranges option to true.
	 */
	@:optional var ranges:Bool;
	/**
	 * It is possible to parse multiple files into a single AST by passing the tree produced 
	 * by parsing the first file as the program option in subsequent parses. This will add the 
	 * toplevel forms of the parsed file to the "Program" (top) node of an existing parse tree.
	 */
	@:optional var program:Dynamic;
	/**
	 * When the locations option is true, you can pass this option to add a source attribute 
	 * in every node’s loc object. Note that the contents of this option are not examined or 
	 * processed in any way; you are free to use whatever format you choose.
	 */
	@:optional var sourceFile:String;
	/**
	 * Like sourceFile, but a sourceFile property will be added (regardless of the location 
	 * option) directly to the nodes, rather than the loc object.
	 */
	@:optional var directSourceFile:String;
	/**
	 * If this option is true, parenthesized expressions are represented by (non-standard) 
	 * ParenthesizedExpression nodes that have a single expression property containing the 
	 * expression inside parentheses.
	 */
	@:optional var preserveParens:Bool;
}

@:jsRequire('acorn/dist/walk')
extern class Walk 
{
	/**
	 * does a 'simple' walk over a tree. node should be the AST node to walk, and visitors an 
	 * object with properties whose names correspond to node types in the ESTree spec. The 
	 * properties should contain functions that will be called with the node object and, if 
	 * applicable the state at that point. The last two arguments are optional. base is a 
	 * walker algorithm, and state is a start state. The default walker will simply visit all 
	 * statements and expressions and not produce a meaningful state. (An example of a use of 
	 * state is to track scope at each point in the tree.)
	 */
	static public function simple(node:AstNode, visitors:Dynamic, ?base:Dynamic, ?state:Dynamic):Void;
	/**
	 * does a 'recursive' walk, where the walker functions are responsible for continuing the 
	 * walk on the child nodes of their target node. state is the start state, and functions 
	 * should contain an object that maps node types to walker functions. Such functions are 
	 * called with (node, state, c) arguments, and can cause the walk to continue on a sub-node 
	 * by calling the c argument on it with (node, state) arguments. The optional base argument 
	 * provides the fallback walker functions for node types that aren't handled in the 
	 * functions object. If not given, the default walkers will be used.
	 */
	static public function recursive(node:AstNode, state:Dynamic, functions:Dynamic, ?base:Dynamic):Void;
}
