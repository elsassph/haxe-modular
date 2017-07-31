import graphlib.Graph;
import haxe.ds.StringMap;
import js.node.Assert;
import acorn.Acorn;

enum ParseStep
{
	Start;
	Definitions;
	Utils;
	StaticInit;
}

class Parser
{
	public var graph:Graph;
	public var rootBody:Array<AstNode>;
	public var isHot:Map<String, Bool>;
	public var isEnum:Map<String, Bool>;
	public var typesCount(default, null):Int;

	var step:ParseStep;
	var types:Map<String, Array<AstNode>>;
	var init:Map<String, Array<AstNode>>;
	var requires:Map<String, AstNode>;

	public function new(src:String)
	{
		var t0 = Date.now().getTime();
		processInput(src);
		var t1 = Date.now().getTime();
		trace('Parsed in: ${t1 - t0}ms');

		buildGraph();
		var t2 = Date.now().getTime();
		trace('Graph processed in: ${t2 - t1}ms');
	}

	function processInput(src:String)
	{
		var program = Acorn.parse(src, { ecmaVersion:5, locations:true, ranges:true });
		walkProgram(program);
	}

	function buildGraph()
	{
		var g = new Graph({ directed: true, compound:true });
		var cpt = 0;
		var refs = 0;
		for (t in types.keys())
		{
			cpt++;
			g.setNode(t, t);
		}

		for (t in types.keys()) refs += walk(g, t, types.get(t));
		for (t in init.keys()) refs += walk(g, t, init.get(t));

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
			}
		};
		for (decl in nodes) Walk.simple(decl, visitors);
		return refs;
	}

	function walkProgram(program:AstNode)
	{
		types = new Map();
		init = new Map();
		requires = new Map();
		isHot = new Map();
		isEnum = new Map();
		step = ParseStep.Start;

		var body = getBodyNodes(program);
		for (node in body)
		{
			switch (node.type)
			{
				case 'ExpressionStatement':
					walkRootExpression(node.expression);
				default:
					throw 'Expecting single root statement in program';
			}
		}
	}

	function walkRootExpression(expr:AstNode)
	{
		switch (expr.type)
		{
			case 'CallExpression':
				walkRootFunction(expr.callee);
			default:
				throw 'Expecting root statement to be a function call';
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
					if (inspectFunction(node.id, node))
					{
						// function marks step change
						continue;
					}
				case 'IfStatement' if (node.consequent.type == 'ExpressionStatement'):
					inspectExpression(node.consequent.expression, node);
				default:
					//trace('----???? ' + node.type);
					//trace(node);
			}
		}
	}

	function inspectFunction(id:AstNode, def:AstNode)
	{
		var path = getIdentifier(id);
		if (path.length > 0)
		{
			//trace('--copy function ${path.join('.')}()');
			switch (path[0])
			{
				case "$extend":
					step = ParseStep.Definitions;
					return true;
				case "$bind":
					step = ParseStep.StaticInit;
					return true;
			}
		}
		return false;
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
							//trace('--copy ' + expression.type);
						case "$hxClasses":
							var moduleName = getIdentifier(expression.right);
							//trace('$$hxClasses[...] = ${moduleName.join('.')}');
							if (moduleName.length == 1)
								//promote(moduleName[0], def);
								append(moduleName[0], def);
						default:
							//trace('${path.join('.')} = ... ' + types.exists(name));
							if (types.exists(name))
							{
								if (path[1] == '__fileName__') trySetHot(name);
								append(name, def);
							}
							//else if (path[1] == '__name__') promote(name, def);
					}
				}
				//else trace('--copy ' + expression.type);
			case 'CallExpression':
				var name = getIdentifier(expression.callee.object);
				var prop = getIdentifier(expression.callee.property);
				if (prop.length > 0 && name.length > 0 && types.exists(name[0]))
				{
					//trace('--${name.join('.')}.${prop.join('.')}()');
					append(name[0], def);
				}
				//else trace('--copy ' + expression.type);
			default:
				//trace('--copy ' + expression.type);
		}
	}

	// identify types with both `displayName` and `__fileName__` as set-up for hotreload
	function trySetHot(name:String)
	{
		var defs = init.get(name);
		if (defs == null || defs.length == 0) return;
		for (def in defs)
		{
			if (def.type == 'ExpressionStatement' && def.expression.type == 'AssignmentExpression')
			{
				var path = getIdentifier(def.expression.left);
				if (path[1] == 'displayName')
				{
					isHot.set(name, true);
					return;
				}
			}
		}
	}

	function inspectDeclarations(declarations:Array<AstNode>, def:AstNode)
	{
		if (step == ParseStep.StaticInit)
			return;

		for (decl in declarations)
		{
			if (decl.id != null)
			{
				var name = decl.id.name;
				//trace('var ${name}');

				if (decl.init != null)
				{
					var init = decl.init;
					switch (init.type)
					{
						case 'FunctionExpression': // ctor
							if (name.charAt(0) != '$') {
								promote(name, def);
							}
						case 'AssignmentExpression' if (init.right.type == 'FunctionExpression'): // ctor with export
							promote(name, def);
						case 'ObjectExpression': // enum
							//trace('(enum?)');
							if (isEnumDecl(init)) {
								isEnum.set(name, true);
								register(name, def);
							}
							else if (name != '__map_reserved') {
								promote(name, def);
							}
						case 'CallExpression' if (isRequire(init.callee)): // require
							//trace('(require)');
							required(name, def);
						case 'MemberExpression' if (init.object.type == 'CallExpression' && isRequire(init.object.callee)): // require with prop
							//trace('(require.something)');
							required(name, def);
						default:
							//trace('--copy ' + decl.type);
					}
				}
				else
				{
					//trace('--copy ' + decl.type);
				}
			}
			else
			{
				//trace('--copy ' + decl.type);
			}
		}
	}

	function required(name:String, def:AstNode)
	{
		requires.set(name, def);
	}

	function register(name:String, def:AstNode)
	{
		def.__tag__ = name;
		types.set(name, [def]);
		init.set(name, []);
	}

	function promote(name:String, def:AstNode)
	{
		if (types.exists(name)) append(name, def);
		else
		{
			def.__tag__ = name;
			types.set(name, [def]);
			init.set(name, []);
		}
	}

	function append(name:String, def:AstNode)
	{
		var defs = step == ParseStep.Definitions ? types.get(name) : init.get(name);
		if (defs != null) {
			def.__tag__ = name;
			defs.push(def);
		}
	}

	function isEnumDecl(node:AstNode)
	{
		var props = node.properties;
		return node.type == 'ObjectExpression'
			&& props != null
			&& props.length > 0
			&& getIdentifier(props[0].key)[0] == '__ename__';
	}

	function isRequire(node:AstNode)
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