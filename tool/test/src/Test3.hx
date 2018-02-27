// Test3 -> CaseC -> DepC -> (SubC, SubC2)
// DepSubC is hoisted in parent of SubC and SubC2 (DepC)
class Test3 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test3')));
		new DepMain();
		Bundle.load(CaseC).then(function(_) new CaseC() );
	}
}
