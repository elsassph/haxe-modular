// Test1 -> (CaseA, CaseB)
// CaseA and CaseB reference DepAB which get hoisted in Test1
class Test1 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test1')));
		Bundle.load(CaseA).then(function(_) new CaseA() );
		Bundle.load(CaseB).then(function(_) new CaseB() );
	}
}
