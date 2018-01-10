import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class RouteBundle
{
	/**
	 * React-router async route bundle created with `classRef` as entry point
	 */
	macro static public function load(reactClassRef:Expr)
	{
		switch (Context.typeof(reactClassRef))
		{
			case Type.TType(_.get() => t, _):
				var module = t.module.split('_').join('_$').split('.').join('_');
				Split.register(module);
				var bridge = macro untyped $i{module} = $p{["$s", module]};
				#if nodejs
				var jsModule = './$module';
				return macro {
					function(_, cb) {
						untyped require($v{jsModule});
						$bridge;
						cb(null, function(props) {
							return react.React.createElement($reactClassRef, props);
						});
					}
				}
				#end
				return macro {
					function(_, cb) {
						#if debug
						Require.hot(function(_) $bridge, $v{module});
						#end
						Require.module($v{module})
							.then(function(id:String) {
								$bridge;
								cb(null, function(props) {
									return react.React.createElement($reactClassRef, props);
								});
							}, function(err:Dynamic) {
								cb(err, null);
							});
					}
				}
			default:
		}
		Context.fatalError('Module bundling needs to be provided a module class reference', Context.currentPos());
		return macro {};
	}
}
