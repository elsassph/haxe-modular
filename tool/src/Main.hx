package;

import js.Node;
import js.node.Fs;
import acorn.Acorn;

class Main
{
	static public function main()
	{
		untyped module.exports = {
			run: run
		};
	}

	static function run(input:String, output:String, modules:Array<String>, debugMode:Bool, webpackMode:Bool)
	{
		// parse input
		var src = Fs.readFileSync(input).toString();
		var parser = new Parser(src);
		var sourceMap = new SourceMap(input, src);

		// process
		var bundler = new Bundler(parser, sourceMap);
		bundler.process(modules, debugMode);

		// emit
		return bundler.generate(src, output, webpackMode);
	}
}
