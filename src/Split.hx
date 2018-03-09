import haxe.Json;
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;

class Split
{
	static var output:String;
	static var tempOutput:String;
	static var bundles:Array<String> = [];

	static public function modules()
	{
		#if closure
		// Closure will be executed by Modular
		Compiler.define('closure_disabled');
		#end

		output = absolute(Compiler.getOutput());
		if (!StringTools.endsWith(output, '.js')) return;

		#if (!modular_stub)
		#if (modular_noprocess)
		tempOutput = output;
		#else
		tempOutput = absolute('.temp/output.js');
		Compiler.setOutput(tempOutput);
		#end

		if (!FileSystem.exists('.temp')) FileSystem.createDirectory('.temp');
		Context.onAfterGenerate(generated);
		#end
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
			#if nodejs '-nodejs', #end
		];
		args = args.concat(bundles).concat(options);

		#if modular_noprocess
		File.saveContent('.temp/split-args.json', Json.stringify(args));
		#else
		//Sys.println(cmd + ' ' + args.join(' '));
		var code = Sys.command(cmd, args);
		if (code != 0) Sys.exit(code);
		else compress();
		#end
	}

	static function compress() {
		#if (closure && !modular_nocompress)
		var path = Path.directory(output);
		var files = [output].concat(bundles.map(function(name) return Path.join([path, name]) + '.js'));
		for (file in files) {
			Sys.println('Compress $file');
			var map = #if closure_create_source_map file + '.map'; #else null; #end
			closure.Compiler.compileFile(file, map);
		}
		#end
	}
}
