package;

import js.Node;
import js.node.Fs;
import acorn.Acorn;

class Main 
{
	static function main() 
	{
		var t0 = Date.now().getTime();
		var input = Node.process.argv[2];
		var output = Node.process.argv[3];
		var modules = Node.process.argv.slice(4);
		
		// parse input
		var src = Fs.readFileSync(input).toString();
		var parser = new Parser(src);
		var sourceMap = new SourceMap(input, src);

		// process
		var t1 = Date.now().getTime();
		var bundler = new Bundler(parser, sourceMap);
		bundler.process(modules);
		
		// emit
		bundler.generate(src, output);
		var t2 = Date.now().getTime();
		trace('Generated in ${t2 - t1}ms');
		trace('Total process in ${t2 - t0}ms');
	}
}
