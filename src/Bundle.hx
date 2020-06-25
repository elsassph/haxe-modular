import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

#if (js_classic)
	#error 'haxe-modular doesn\'t work with -D js-classic'
#end

class Bundle
{
	/**
	 * Load async application bundle created with `classRef` as entry point
	 * Note: excution is synchronous in nodejs; the Promise can be ignored
	 */
	macro static public function load(classRef:Expr, ?bundleNameExpr:Expr)
	{
		switch (Context.typeof(classRef))
		{
			case Type.TType(_.get() => t, _):
				var module = t.module.split('_').join('_$').split('.').join('_');
				var bundleName = getStringOption(bundleNameExpr);
				if (bundleName != null) {
					Split.register('$module>$bundleName');
				} else {
					bundleName = module;
					Split.register(module);
				}
				#if modular_stub
				return macro ({ then: function(cb) { cb($v{module}); }});
				#else

				var bridge = macro var _ = untyped $i{module} = $p{["$s", module]};
				#if nodejs
				var jsModule = './$bundleName';
				return macro cast {
					untyped require($v{jsModule});
					$bridge;
					#if (haxe_ver >= 4)
					js.lib.Promise.resolve($v{module});
					#else
					js.Promise.resolve($v{module});
					#end
				}
				#else
				return macro {
					#if debug
					Require.hot(function(_) $bridge, $v{module});
					#end
					@:keep Require.module($v{bundleName})
						.then(function(_i:String) {
							$bridge;
							return _i;
						});
				}
				#end
				#end
			default:
				Context.fatalError('Module bundling needs to be provided a module class reference', Context.currentPos());
		}
		return macro {};
	}

	macro static public function loadLib(libNameExpr:Expr, pkgListExpr:Expr)
	{
		var libName = getString(libNameExpr);

		switch (pkgListExpr.expr) {
			case EArrayDecl(values):
				var pattern = values
					.map(getString)
					.map(formatMatch)
					.join(',');
				var module = '$libName=$pattern';
				var bridge = '"${libName}__BRIDGE__"';
				Split.register(module);

				#if modular_stub
				return macro ({ then: function(cb) { cb($v{libName}); }});
				#else

				return macro {
					@:keep Require.module($v{libName})
						.then(function(id:String) {
							untyped __js__($v{bridge});
							return id;
						});
				}
				#end

			default:
				Context.fatalError('Array of string literals expected', pkgListExpr.pos);
		}
		return macro {};
	}

	#if macro
	static function getString(e:Expr) {
		switch (e.expr) {
			case EConst(CString(s)): return s;
			default:
				Context.fatalError('String literal expected', e.pos);
				return null;
		}
	}

	static function getStringOption(e:Expr) {
		switch (e.expr) {
			case EConst(CString(s)): return s;
			default: return null;
		}
	}

	static function formatMatch(s:String)
	{
		var m = s.split('_').join('_$').split('.').join('_');
		return ~/_[A-Z]/.match(m) ? m : m += '_';
	}
	#end
}
