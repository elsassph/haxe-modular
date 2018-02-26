// Test4 -> lib / (CaseA, CaseB)
// CaseA and CaseB use classes from lib
class Test4 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test4')));
		new DepMain();
		Bundle.loadLib('lib', ['lib']).then(function(_) {
			Bundle.load(CaseA).then(function(_) new CaseA() );
			Bundle.load(CaseB).then(function(_) new CaseB() );
		});
	}
}
