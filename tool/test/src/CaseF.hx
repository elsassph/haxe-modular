class CaseF {
	static var b:Bool;
	var s:String;

	public function new() {
		trace('CaseF');
		if (b != true) throw 'Wrapped not called';
		if (s != 'direct') throw 'Getter not setup: ' + s;
	}

	static function wrapped() {
		b = true;
	}

	static function __init__() {
		wrapped();

		untyped Object.defineProperty((cast CaseF).prototype, 's', {
			get: function() return 'getter'
		});
	}
}
