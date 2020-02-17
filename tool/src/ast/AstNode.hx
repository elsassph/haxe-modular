package ast;

typedef AstPosition = {
	line: Int,
	column: Int
}

typedef AstSourceLocation = {
	source: String,
	start: AstPosition,
	end: AstPosition
}

extern interface AstNode {
	var __tag__: String;
	var __main__: Bool;
	var raw: String;
	var type: String;
	var loc: AstSourceLocation;
	var source: String;
	var start: Int;
	var end: Int;
	var range: Array<Int>;
	var body: haxe.extern.EitherType<AstNode, Array<AstNode>>;
	// ExpressionStatement
	var expression: AstNode;
	// CallExpression
	var callee: AstNode;
	var arguments: Array<AstNode>;
	// FunctionExpression
	var params: Array<AstNode>;
	// Identifier
	var name: String;
	// Literal
	var value: String;
	var rawvar : String;
	// ConditionalExpression/IfStatement
	var test: AstNode;
	var consequent: AstNode;
	var alternate: AstNode;
	// VariableDeclaration
	var declarations: Array<AstNode>;
	// VariableDeclarator
	var id: AstNode;
	var init: AstNode;
	// AssignmentExpression
	var left: AstNode;
	var right: AstNode;
	// LogicalExpression
	@:native('operator') var op: String;
	// MemberExpression
	var object: AstNode;
	var property: AstNode;
	var computer: Bool;
	// ObjectExpression
	var properties: Array<AstNode>;
	// Property
	var key: AstNode;
}
