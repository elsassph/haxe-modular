import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class Bundle
{
	/**
	 * Load async application bundle created with `classRef` as entry point
	 * Note: excution is synchronous in nodejs; the Promise can be ignored
	 */
	macro static public function load(classRef:Expr)
	{
		switch (Context.typeof(classRef))
		{
			case Type.TType(_.get() => t, _):
				var module = t.module.split('_').join('_$').split('.').join('_');
				Split.register(module);
				var bridge = macro var _ = untyped $i{module} = $p{["$s", module]};
				#if nodejs
				var jsModule = './$module';
				return macro cast {
					untyped require($v{jsModule});
					$bridge;
					js.Promise.resolve($v{module});
				}
				#else
				return macro {
					#if debug
					Require.hot(function(_) $bridge, $v{module});
					#end
					@:keep Require.module($v{module})
						.then(function(id:String) {
							$bridge;
							return id;
						});
				}
				#end
			default:
				Context.fatalError('Module bundling needs to be provided a module class reference', Context.currentPos());
		}
		return macro {};
	}

	macro static public function loadLib(libNameExpr:Expr, pkgListExpr:Expr)
	{
		function getString(e:Expr) {
			switch (e.expr) {
				case EConst(CString(s)): return s;
				default:
					Context.fatalError('String literal expected', e.pos);
					return null;
			}
		}

		var libName = getString(libNameExpr);

		switch (pkgListExpr.expr) {
			case EArrayDecl(values):
				var pattern = values
					.map(getString)
					.map(function(v:String) return v.split('_').join('_$').split('.').join('_') + '_')
					.join('|');
				var module = '$libName=$pattern';
				var bridge = '${libName}__BRIDGE__';
				Split.register(module);
				return macro {
					@:keep Require.module($v{libName})
						.then(function(id:String) {
							var _ = $v{bridge};
							return id;
						});
				}

			default:
				Context.fatalError('Array of string literals expected', pkgListExpr.pos);
		}
		return macro {};
	}
}
