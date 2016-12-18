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
	
	var step:ParseStep;
	var candidates:Map<String, AstNode>;
	var types:Map<String, Array<AstNode>>;
	var init:Map<String, Array<AstNode>>;
	var requires:Map<String, AstNode>;

	public function new(src:String) 
	{
		var t0 = Date.now().getTime();
		processInput(src);
		var t1 = Date.now().getTime();
		trace('Parsed in ${t1 - t0}ms');
		
		buildGraph();
		var t2 = Date.now().getTime();
		trace('Graph processed in ${t2 - t1}ms');
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
		var ids = 0;
		var refs = 0;
		for (t in types.keys())
		{
			cpt++;
			g.setNode(t, t);
		}
		
		for (t in types.keys())
		{
			var ns = types.get(t);
			for (n in ns)
			{
				Walk.simple(n, {
					Identifier: function(node:AstNode) {
						ids++;
						var name = node.name;
						if (name != t && types.exists(name)) 
						{
							g.setEdge(t, name);
							refs++;
						}
					}
				});
			}
		}
		for (t in init.keys())
		{
			var ns = init.get(t);
			for (n in ns)
			{
				Walk.simple(n, {
					Identifier: function(node:AstNode) {
						ids++;
						var name = node.name;
						if (name != t && types.exists(name)) 
						{
							g.setEdge(t, name);
							refs++;
						}
					}
				});
			}
		}
		
		trace('Stats: $cpt types, $ids ids, $refs refs');
		graph = g;
	}
	
	function walkProgram(program:AstNode) 
	{
		candidates = new Map();
		types = new Map();
		init = new Map();
		requires = new Map();
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
				default:
					//trace('----????');
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
					//trace('---------------- DEFS');
					return true;
				case "$bind":
					step = ParseStep.StaticInit;
					//trace('---------------- INIT');
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
								promote(moduleName[0], def);
						default:
							//trace('${path.join('.')} = ...');
							if (types.exists(name)) append(name, def);
							else if (path[1] == '__name__') promote(name, def);
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
							candidates.set(name, def);
						case 'AssignmentExpression' if (init.right.type == 'FunctionExpression'): // ctor with export
							candidates.set(name, def);
						case 'ObjectExpression': // enum
							//trace('(enum?)');
							if (isEnum(init)) register(name, def);
							else candidates.set(name, def);
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
		if (candidates.exists(name))
		{
			//trace('type: $name');
			var cDef = candidates.get(name);
			candidates.remove(name);
			cDef.__tag__ = name;
			def.__tag__ = name;
			types.set(name, [cDef, def]);
			init.set(name, []);
		}
		else if (types.exists(name)) 
		{
			append(name, def);
		}
	}
	
	function append(name:String, def:AstNode) 
	{
		def.__tag__ = name;
		var defs = step == ParseStep.Definitions ? types.get(name) : init.get(name);
		defs.push(def);
	}
	
	function isEnum(node:AstNode) 
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