package;

class Run
{
	static public function main() 
	{
		var args = Sys.args();
		if (args.length < 3)
		{
			Sys.println('Haxe-JS code splitting, usage:');
			Sys.println('');
			Sys.println('  haxelib run modular <path to input.js> <path to main output.js> <module name 1> [<module name 2> ...]');
			Sys.println('');
			return;
		}
		
		// call nodejs source processor
		var workingDir = args.pop();
		var path = Sys.programPath().split('run.n')[0];
		args.unshift(path + 'tool/bin/split.js');
		Sys.command('node',  args);
	}
}