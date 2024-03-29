import haxe.Timer;
import haxe.macro.Expr;

#if (!webpack && !nodejs)
#if (haxe_ver >= 4)
typedef Promise<T> = js.lib.Promise<T>;
#else
typedef Promise<T> = js.Promise<T>;
#end
#end

class Require
{
	#if (!webpack && !nodejs)
	static public var jsPath = './';
	static public var jsExt = '.js';

	static var loaded:Map<String, Promise<String>> = new Map();
	static var handlers:Map<String, String -> Void> = new Map();

	#if debug
	static var isHot:Bool;
	static var dirty:Array<String> = [];
	static var reloadTimer:Timer;
	#end

	/**
	 * Load JS module
	 * @param	name	JS file name without extension
	 */
	static public function module(name:String):Promise<String>
	{
		if (loaded.exists(name))
			return loaded.get(name);

		var p = new Promise<String>(function(resolve, reject) {
			var doc = js.Browser.document;
			var script:js.html.ScriptElement = null;
			var hasFailed:Bool = false;

			function resourceLoaded(_)
			{
				resolve(name);
			}
			function resourceFailed(_)
			{
				if (!hasFailed)
				{
					hasFailed = true;

					loaded.remove(name); // retry
					doc.body.removeChild(script);

					reject(name);
				}
			}

			script = doc.createScriptElement();
			script.onload = resourceLoaded;
			script.onerror = resourceFailed;
			script.src = jsPath + name + jsExt;
			doc.body.appendChild(script);
		});

		loaded.set(name, p);
		return p;
	}

	#if debug
	/**
		Set livereload handler, either for all modules or a specific module
	**/
	static public function hot(?handler:String -> Void, ?forModule:String)
	{
		if (handler != null)
		{
			if (forModule == null) forModule = '*';
			handlers.set(forModule, handler);
		}

		if (!isHot)
		{
			isHot = true;
			js.Browser.document.addEventListener('LiveReloadConnect', function(_) {
				untyped window.LiveReload.reloader.plugins.push({
					reload: Require.reload
				});
			});
		}
	}

	static function reload(path:String, options:Dynamic)
	{
		if (path.indexOf('.js') > 0) {
			var module = path.split('.')[0];
			if (loaded.exists(module) && dirty.indexOf(module) < 0) {
				dirty.push(module);
				if (reloadTimer == null) reloadTimer = Timer.delay(reloadDirty, 100);
			}
			return true;
		}
		return false;
	}

	static function reloadDirty()
	{
		var modules = dirty;
		dirty = [];
		reloadTimer = null;
		trace('Reloading ${modules}...');

		Promise.all([for (module in modules) {
			var script = js.Browser.document.querySelector('script[src$="$module.js"]');
			if (script != null) script.remove();
			loaded.remove(module);
			Require.module(module);
		}])
		.then(function(_) {
			for (module in modules) {
				trace('Module [$module] reloaded');
				trigger(module);
			}
			trigger('*');
		});
	}

	static function trigger(module:String)
	{
		if (handlers.exists(module))
			handlers.get(module)(module);
	}
	#end

	#else //webpack/nodejs
	static macro public function module(name:Expr)
	{
		var module = switch(name.expr) {
			case EConst(CString(s)): s;
			default: throw 'Modules should be required by String literal name';
		}
		#if (haxe_ver >= 4.1)
		return macro js.Syntax.code('import')($v{'./' + module});
		#else
		return macro untyped __js__('import')($v{'./' + module});
		#end
	}

	static public function hot(?handler:String -> Void, ?forModule:String)
	{
		// not implemented
	}
	#end
}
