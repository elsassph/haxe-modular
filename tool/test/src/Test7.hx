// Test7 -> CaseD
// Load purely static module
class Test7 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test7')));
		Bundle.load(CaseD).then(function(_) CaseD.init() );
	}
}
