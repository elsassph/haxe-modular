// Test10 -> CaseE -> Test10
// Module references entry point
class Test10 {
	static public var SECRET = 'secret';
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test10')));
		Bundle.load(CaseE).then(function(_) trace('ok'));
	}
}
