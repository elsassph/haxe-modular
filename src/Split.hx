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
		output = absolute(Compiler.getOutput());
		if (!StringTools.endsWith(output, '.js')) return;

		#if !kha
		// generate in temp directory for processing
		if (!FileSystem.exists('.temp')) FileSystem.createDirectory('.temp');
		tempOutput = absolute('.temp/output.js');
		Compiler.setOutput(tempOutput);
		#end

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
		if (bundles.indexOf(module) < 0)
			bundles.push(module);
	}

	static function generated()
	{
		#if kha
		if (Compiler.getDefine('js-classic') != null) {
			trace('Worker mode not supported');
			return;
		}
		tempOutput = output;
		#end

		var args = [tempOutput, output];

		// resolve haxe-split
		#if haxe_split
		var params = Std.string(Compiler.getDefine('haxe_split')).split(' ');
		var cmd = params.shift();
		if (params.length > 0) args = params.concat(args);

		#else
		var cmd = Sys.systemName() == 'Windows'
			? 'node_modules\\.bin\\haxe-split.cmd'
			: './node_modules/.bin/haxe-split';
		if (!FileSystem.exists(cmd)) cmd = 'haxe-split'; // try global
		#end

		// emit the bundles
		var options = [
			#if (debug && !modular_nomaps) '-debug', #end
			#if webpack '-webpack', #end
			#if modular_dump '-dump', #end
			#if modular_debugmap '-debugmap', #end
			#if (nodejs || kha_debug_html5) '-nodejs', #end
		];
		args = args.concat(bundles).concat(options);

		//Sys.println(cmd + ' ' + args.join(' '));
		var code = Sys.command(cmd, args);
		if (code != 0) Sys.exit(code);
	}
}
