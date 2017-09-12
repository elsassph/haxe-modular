import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.FileSystem;

class Split
{
	static var output:String;
	static var tempOutput:String;
	static var bundles:Array<String> = [];

	static public function modules()
	{
		// generate in temp directory for processing
		if (!FileSystem.exists('.temp')) FileSystem.createDirectory('.temp');

		output = absolute(Compiler.getOutput());
		tempOutput = absolute('.temp/output.js');
		Compiler.setOutput(tempOutput);

		Context.onAfterGenerate(generated);
	}

	static function absolute(path:String)
	{
		#if (haxe_ver < 3.2)
		return Path.normalize(Path.join([Sys.getCwd(), path]));
		#else
		return FileSystem.absolutePath(path);
		#end
	}

	static public function register(module:String)
	{
		bundles.push(module);
	}

	static function generated()
	{
		// emit the bundles
		var cmd = Sys.systemName() == 'Windows'
			? 'node_modules\\.bin\\haxe-split.cmd'
			: './node_modules/.bin/haxe-split';
		if (!FileSystem.exists(cmd)) cmd = 'haxe-split'; // try global

		var options = [
			#if debug '-debug', #end
			#if webpack '-webpack', #end
			#if modular_dump '-dump', #end
		];

		var args = [tempOutput, output].concat(bundles).concat(options);
		Sys.command(cmd, [tempOutput, output].concat(bundles).concat(options));
	}
}
