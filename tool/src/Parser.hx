import graphlib.Graph;
import haxe.DynamicAccess;
import acorn.Acorn;

class Parser
{
	public var graph:Graph;
	public var rootExpr:AstNode;
	public var rootBody:Array<AstNode>;
	public var isHot:DynamicAccess<Bool>;
	public var isEnum:DynamicAccess<Bool>;
	public var isRequire:DynamicAccess<Bool>;
	public var typesCount(default, null):Int;
	public var mainModule:String = 'Main';

	var reservedTypes:DynamicAccess<Bool> = {
		'String':true, 'Math':true, 'Array':true, 'Date':true, 'Number':true, 'Boolean':true,
		__map_reserved:true
	};
	var objectMethods:DynamicAccess<Bool> = {
		'defineProperty':true, 'defineProperties':true, 'freeze':true
	};

	var types:DynamicAccess<Array<AstNode>>;

	public function new(src:String, withLocation:Bool, commonjs:Bool)
	{
		var t0 = Date.now().getTime();
		processInput(src, withLocation);
		var t1 = Date.now().getTime();
		trace('Parsed in: ${t1 - t0}ms');

		buildGraph(commonjs);
		var t2 = Date.now().getTime();
		trace('AST processed in: ${t2 - t1}ms');
	}

	function processInput(src:String, withLocation:Bool)
	{
		var options:AcornOptions = { ecmaVersion: 5, allowReserved: true };
		if (withLocation) options.locations = true;
		var program = Acorn.parse(src, options);
		walkProgram(program);
	}

	function buildGraph(commonjs:Bool)
	{
		var g = new Graph({ directed: true, compound:true });
		var cpt = 0;
		var refs = 0;
		for (t in types.keys()) {
			cpt++;
			g.setNode(t, t);
		}

		if (!commonjs) {
			// require stub is generated in web entry point
			types.set('require', []);
			g.setNode('require', 'require');
			g.setEdge(mainModule, 'require');
		}

		for (t in types.keys())
			refs += walk(g, t, types.get(t));

		trace('Stats: $cpt types, $refs references');
		typesCount = cpt;
		graph = g;
	}

	function walk(g:Graph, id:String, nodes:Array<AstNode>)
	{
		var refs = 0;
		var visitors = {
			Identifier: function(node:AstNode) {
				var name = node.name;
				if (name != id && types.exists(name))
				{
					g.setEdge(id, name);
					refs++;
				}
			},
			AssignmentExpression: function(node, state, cont) {
				// force exploring both right and left of expression
				cont(node.right, state);
				cont(node.left, state);
			}
		};
		for (decl in nodes) Walk.recursive(decl, {}, visitors);
		return refs;
	}

	function walkProgram(program:AstNode)
	{
		types = {};
		isEnum = {};
		isRequire = {};

		// allow code to have been included before the Haxe output
		var body = getBodyNodes(program);
		rootExpr = body.pop();

		switch (rootExpr.type)
		{
			case 'ExpressionStatement':
				walkRootExpression(rootExpr.expression);
			default:
				throw 'Expecting last node to be an ExpressionStatement';
		}
	}

	function walkRootExpression(expr:AstNode)
	{
		switch (expr.type)
		{
			case 'CallExpression':
				walkRootFunction(expr.callee);
			default:
				throw 'Expecting last node statement to be a function call';
		}
	}

	function walkRootFunction(callee:AstNode)
	{
		var block = getBodyNodes(callee)[0];
		switch (block.type)
		{
			case 'BlockStatement':
				var body = getBodyNodes(block);
				walkDeclarations(body);
			default:
				throw 'Expecting block of statements inside root function';
		}
	}

	function walkDeclarations(body:Array<AstNode>)
	{
		rootBody = body;

		for (node in body)
		{
			switch (node.type)
			{
				case 'VariableDeclaration':
					inspectDeclarations(node.declarations, node);
				case 'ExpressionStatement':
					inspectExpression(node.expression, node);
				case 'FunctionDeclaration':
					inspectFunction(node.id, node);
				case 'IfStatement':
					if (node.consequent.type == 'ExpressionStatement')
						inspectExpression(node.consequent.expression, node);
					else
						inspectIfStatement(node.test, node);
				case 'EmptyStatement':
					// ignore
				default:
					trace('WARNING: Unexpected ${node.type}, at character ${node.start}');
			}
		}
	}

	function inspectIfStatement(test:AstNode, def:AstNode)
	{
		if (test.type == 'BinaryExpression')
		{
			// conditional prototype modification
			// eg. if(ArrayBuffer.prototype.slice == null) {...}
			var path = getIdentifier(test.left);
			if (path.length > 1 && path[1] == 'prototype')
				tag(path[0], def);
		}
	}

	function inspectFunction(id:AstNode, def:AstNode)
	{
		var path = getIdentifier(id);
		if (path.length > 0)
		{
			var name = path[0];
			if (name == "$extend" || name == "$bind" || name == "$iterator") tag(name, def);
		}
	}

	function inspectExpression(expression:AstNode, def:AstNode)
	{
		switch (expression.type)
		{
			case 'AssignmentExpression':
				var path = getIdentifier(expression.left);
				if (path.length > 0)
				{
					var name = path[0];
					switch (name)
					{
						case "$hx_exports":
						case "$hxClasses":
							var moduleName = getIdentifier(expression.right);
							if (moduleName.length == 1) tag(moduleName[0], def);
						default:
							if (types.exists(name))
							{
								if (path[1] == 'displayName') trySetHot(name);
								else if (path[1] == '__fileName__') trySetHot(name);
							}
							tag(name, def);
					}
				}
			case 'CallExpression':
				var path = getIdentifier(expression.callee.object);
				var prop = getIdentifier(expression.callee.property);
				if (prop.length == 1 && path.length == 1) {
					var name = path[0];
					var member = prop[0];
					// eg. SomeType.something()
					if (types.exists(name)) {
						// last SomeType.main() call is the entry point
						if (member == 'main') mainModule = name;
						tag(name, def);
					}
					// eg. Object.defineProperty(SomeType.prototype, ...)
					else if (name == 'Object' && objectMethods.get(member)
						&& expression.arguments != null && expression.arguments[0] != null) {
						path = getIdentifier(expression.arguments[0].object);
						if (path.length == 1) {
							name = path[0];
							if (types.exists(name)) tag(name, def);
						}
					}
				}
			default:
		}
	}

	// Identify types with both `displayName` and `__fileName__` as set-up for hotreload
	function trySetHot(name:String)
	{
		if (isHot == null) isHot = {};
		// first set isHot to false, then true when both properties are seen
		if (isHot.exists(name)) isHot.set(name, true);
		else isHot.set(name, false);
	}

	function inspectDeclarations(declarations:Array<AstNode>, def:AstNode)
	{
		for (decl in declarations)
		{
			if (decl.id != null)
			{
				var name = decl.id.name;
				if (decl.init != null)
				{
					var init = decl.init;
					switch (init.type)
					{
						case 'FunctionExpression': // ctor
							tag(name, def);
						case 'AssignmentExpression':
							var right = init.right;
							var type = right.type;
							if (type == 'FunctionExpression') { // ctor with export
								tag(name, def);
							}
							else if (type == 'ObjectExpression') { // enum with export
								if (isEnumDecl(right))
									isEnum.set(name, true);
								tag(name, def);
							}
							else if (type == 'Identifier') { // var Float = Number
								tag(name, def);
							}
						case 'ObjectExpression': // enum
							if (isEnumDecl(init))
								isEnum.set(name, true);
							tag(name, def);
						case 'CallExpression':
							if (isRequireDecl(init.callee))
								required(name, def);
						case 'MemberExpression':
							// jsRequire with prop
							if (init.object.type == 'CallExpression' && isRequireDecl(init.object.callee))
								required(name, def);
						case 'Identifier':
							// eg. var Float = Number;
							if (name.charAt(0) != '$')
								tag(name, def);
						case 'LogicalExpression':
							// eg. var ArrayBuffer = $global.ArrayBuffer || js_html_compat_ArrayBuffer;
							if (name == "$hxEnums") // workaround for: $hxEnums = $hxEnums || {}
								tag(name, def);
							else if (init.op == '||' && init.right != null) {
								var id = getIdentifier(init.right);
								if (id.length > 0 && id[0].indexOf('_compat_') > 0)
									tag(name, def);
							}
						default:
					}
				}
			}
		}
	}

	function required(name:String, def:AstNode)
	{
		isRequire.set(name, true);
		tag(name, def);
	}

	function tag(name:String, def:AstNode)
	{
		if (!types.exists(name)) {
			if (reservedTypes.get(name)) {
				// Tag types we want to include only in main module (eg. 'Math.__name__ = "Math";)
				// but 'var __map_reserved = {}' is better to just include everywhere
				if (name !=  '__map_reserved') def.__tag__ = '__reserved__';
				return;
			}
			types.set(name, [def]);
		}
		else types.get(name).push(def);
		if (def.__tag__ == null) def.__tag__ = name;
	}

	function isEnumDecl(node:AstNode)
	{
		var props = node.properties;
		return node.type == 'ObjectExpression'
			&& props != null
			&& props.length > 0
			&& getIdentifier(props[0].key)[0] == '__ename__';
	}

	function isRequireDecl(node:AstNode)
	{
		return node != null && node.type == 'Identifier' && node.name == 'require';
	}

	function getBodyNodes(node:AstNode):Array<AstNode>
	{
		return Std.is(node.body, Array)
			? cast node.body
			: [cast node.body];
	}

	function getIdentifier(left:AstNode)
	{
		if (left == null) return [];
		switch (left.type)
		{
			case 'Identifier':
				return [left.name];
			case 'MemberExpression':
				return getIdentifier(left.object).concat(getIdentifier(left.property));
			case 'Literal':
				return [left.raw];
			default:
				return [];
		}
	}
}