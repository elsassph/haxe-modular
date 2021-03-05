import a_b.C__d;

class CaseInterop {
	public function new() {
		trace('CaseInterop');
		var i = cast(value, Int);
		var f = cast(value, Float);
		trace(haxe.Timer.stamp());

		Bundle.load(C__d).then(function(_) {
			new C__d();
			#if !nodejs
			// verify HTML compat classes
			var d = new js.html.DataView(new js.html.ArrayBuffer(2));
			// verify sharing of $estr (Haxe 3 valid only)
			var estr = untyped __js__("$estr");
			var m = js.Lib.require('foo');
			#end
		});
	}

	static public var value: Int;
	static function __init__() {
		var v = 42;
		CaseInterop.value = v;
	}
}
