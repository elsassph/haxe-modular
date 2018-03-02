// Test9 -> CaseD
// Module has internal cyclic references (e.g. not orphan), and no reference from entry point
class Test9 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test9')));
		Bundle.load(CaseD).then(function(_) trace('ok'));
	}
}
