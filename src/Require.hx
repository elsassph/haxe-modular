import haxe.Timer;
import js.Browser;
import js.html.LinkElement;
import js.html.ScriptElement;
import js.Promise;

class Require
{
	static public var jsPath = './';
	static public var cssPath = './';
	
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
	 * @param	loadCss	Please also load a CSS of the same name
	 */
	static public function module(name:String, loadCss:Bool = false):Promise<String>
	{
		if (loaded.exists(name)) 
			return loaded.get(name);
		
		var p = new Promise<String>(function(resolve, reject) {
			var doc = Browser.document;
			var pending = loadCss ? 2 : 1;
			var css:LinkElement = null;
			var script:ScriptElement = null;
			var hasFailed:Bool = false;
			
			function resourceLoaded() 
			{
				if (--pending == 0) 
					resolve(name);
			}
			function resourceFailed()
			{
				if (!hasFailed)
				{
					hasFailed = true;
					
					loaded.remove(name); // retry
					if (css != null) doc.body.removeChild(css);
					doc.body.removeChild(script);
					
					reject(name);
				}
			}
			
			if (loadCss)
			{
				css = doc.createLinkElement();
				css.rel = 'stylesheet';
				css.onload = resourceLoaded;
				css.onerror = resourceFailed;
				css.href = cssPath + name + '.css';
				doc.body.appendChild(css);
			}
			
			script = doc.createScriptElement();
			script.onload = resourceLoaded;
			script.onerror = resourceFailed;
			script.src = jsPath + name + '.js';
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
			Browser.document.addEventListener('LiveReloadConnect', function() {
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
			var script = Browser.document.querySelector('script[src$="$module.js"]');
			if (script != null) script.remove();
			loaded.remove(module);
			Require.module(module, false);
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
}
