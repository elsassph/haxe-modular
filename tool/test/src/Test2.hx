// Test2 -> (CaseA, CaseB)
// Test2, CaseA and CaseB reference DepAB
class Test2 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test2')));
		Bundle.load(CaseA).then(function(_) new CaseA() );
		Bundle.load(CaseB).then(function(_) new CaseB() );
		new DepAB();
	}
}
