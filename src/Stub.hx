#if macro
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Type;
import sys.FileSystem;
import sys.io.File;

/**
	Modular Haxe JS output processor
**/
class Stub
{
	#if (haxe_ver < 3.3)
	static inline var SCOPE = 'typeof window != "undefined" ? window : exports';
	static inline var RE_EXPORT = '\\$$hx_exports\\.([a-z0-9_]+) = \\$';
	#else
	static inline var SCOPE = 'typeof exports != "undefined" ? exports : typeof window != "undefined" ? window : typeof self != "undefined" ? self : this';
	static inline var RE_EXPORT = '\\$$hx_exports\\["([a-z0-9_]+)"] = \\$';
	#end
	static var sharedPackages:Array<String>;
	
	static public function modules(?sharedPackages:Array<String>) 
	{
		// auto-expose all types in the shared packages
		// note: Enums can NOT be exposed
		Stub.sharedPackages = sharedPackages;
		Context.onGenerate(autoExpose);
		
		// patch output for automatic joining of modules scopes
		Context.onAfterGenerate(generated);
	}
	
	static function autoExpose(types:Array<haxe.macro.Type>) 
	{
		for (type in types) 
		{
			switch (type)
			{
				case TInst(_.get() => t, _):
					if (shouldExpose(t.module))
						t.meta.add(':expose', [], Context.currentPos());
				default:
			}
		}
	}
	
	static private function shouldExpose(module:String) 
	{
		if (sharedPackages == null) return false;
		for (pkg in sharedPackages)
			if (module.indexOf(pkg) == 0) return true;
		return false;
	}
	
	static function generated() 
	{
		var output = Compiler.getOutput();
		if (!FileSystem.exists(output)) return;
		
		var moduleName = Path.withoutDirectory(Path.withoutExtension(output));
		
		var src = File.getContent(output);
		
		// find exposed modules packages and store their position
		// eg. 'com' for 'com.common': $hx_exports.com = $hx_exports.com || {};
		var reExport = new EReg(RE_EXPORT, 'gi');
		var search = src;
		var refs = new Array<String>();
		var indexes = new Array<Int>();
		var offset = 0;
		while (reExport.match(search))
		{
			var name = reExport.matched(1);
			refs.push(name);
			var pos = reExport.matchedPos();
			indexes.push(offset + pos.pos);
			search = reExport.matchedRight();
			offset += pos.pos + pos.len;
		}
		
		// process output
		src = addInjections(refs, indexes, src);
		src = addJoinPoint(src);
		src = addRequire(src);
		
		File.saveContent(output, src);
	}
	
	/**
	 * Provide a `require` function which will lookup modules in the shared registry
	 */
	static function addRequire(src:String) 
	{
		var p = src.indexOf('"use strict"');
		if (p < 0) return src;
		return src.substr(0, p + 12)
			+ '; var require = (function(r){return function require(m){return r[m];}})($$hx_exports.__registry__)'
			+ src.substr(p + 12);
	}
	
	/**
	 * Stub local variable for exposed packages
	 * eg. var com = $hx_exports.com = $hx_exports.com || {};
	 */
	static function addInjections(refs:Array<String>, indexes:Array<Int>, src:String) 
	{
		var i = indexes.length - 1;
		while (i >= 0)
		{
			src = src.substr(0, indexes[i])
				+ 'var ${refs[i]} = ' 
				+ src.substr(indexes[i]);
			i--;
		}
		return src;
	}
	
	/**
	 * Make the global (shared) context a "private" variable instead of window/exports
	 */
	static function addJoinPoint(src:String) 
	{
		return StringTools.replace(src, SCOPE, 
			'typeof $$hx_scope != "undefined" ? $$hx_scope : $$hx_scope = {}');
	}
	
}
#end