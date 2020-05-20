import a_b.C__d;

class CaseInterop {
	public function new() {
		trace('CaseInterop');
		var i = cast(0, Int);
		var f = cast(0, Float);

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
}
