// Test12 -> lib * 2
// Test12, lib should be combined
class Test12 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test12')));
		new DepMain();
		Bundle.loadLib('lib', ['lib']).then(function(_) {
			new lib.Lib.Lib2();
		});
		Bundle.loadLib('lib', ['a_b.C__d']).then(function(_) {
			new a_b.C__d();
		});
	}
}