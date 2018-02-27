// Test6 -> CaseA
// Load module through reflected class and getter
class Test6 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test6')));
		var r:Reflected = Type.createInstance(Type.resolveClass('Reflected'), []);
		r.a.then(function(_) new CaseA() );
	}
}

class Reflected {
	public var a(get, null):Dynamic;

	public function new() {
		trace('Reflected');
	}

	function get_a():Dynamic
	{
		return Bundle.load(CaseA);
	}
}
