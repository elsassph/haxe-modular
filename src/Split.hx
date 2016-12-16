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
		output = FileSystem.absolutePath(Compiler.getOutput());
		tempOutput = FileSystem.absolutePath('.temp/output.js');
		Compiler.setOutput(tempOutput);
		
		Context.onAfterGenerate(generated);
	}
	
	static public function register(module:String)
	{
		bundles.push(module);
	}
	
	static function generated()
	{
		// emit the bundles
		Sys.command('haxelib', ['run', 'modular', tempOutput, output].concat(bundles));
	}
}