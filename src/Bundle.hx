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
				var bridge = macro untyped $i{module} = $p{["$s", module]};
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
					Require.module($v{module})
						.then(function(id:String) {
							$bridge;
							return id;
						});
				}
				#end
			default:
		}
		Context.fatalError('Module bundling needs to be provided a module class reference', Context.currentPos());
		return macro {};
	}
}
