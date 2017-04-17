package;

import js.Node;
import js.node.Fs;
import acorn.Acorn;

class Main
{
	static function main()
	{
		var args = Node.process.argv.copy();
		var debugMode = args.remove('-debug');

		if (args.length < 3)
		{
			Sys.println('Haxe-JS code splitting, usage:');
			Sys.println('');
			Sys.println('  haxe-split <path to input.js> <path to main output.js> [<module name 1> <module name 2> ...]');
			Sys.println('');
			return;
		}

		var t0 = Date.now().getTime();
		var input = args[2];
		var output = args[3];
		var modules = args.slice(4);

		// parse input
		var src = Fs.readFileSync(input).toString();
		var parser = new Parser(src);
		var sourceMap = new SourceMap(input, src);

		// process
		var t1 = Date.now().getTime();
		var bundler = new Bundler(parser, sourceMap);
		bundler.process(modules, debugMode);

		// emit
		bundler.generate(src, output);
		var t2 = Date.now().getTime();
		trace('Generated in ${t2 - t1}ms');
		trace('Total process in ${t2 - t0}ms');
	}
}
