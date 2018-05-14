// Test5 -> lib / (CaseA, CaseB)
// Test5, CaseA and CaseB use classes from lib
class Test5 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test5')));
		new DepMain();
		Bundle.loadLib('lib', ['lib', 'a_b.C__d']).then(function(_) {
			new lib.Lib.Lib2();
			new a_b.C__d();
			Bundle.load(CaseA).then(function(_) new CaseA() );
			Bundle.load(CaseB).then(function(_) new CaseB() );
		});
	}
}
