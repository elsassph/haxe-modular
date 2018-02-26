// Test8 -> X
// Module call site removed by DCE
class Test8 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test8')));
	}

	static function unused() {
		Bundle.load(CaseD).then(function(_) CaseD.init() );
	}
}
