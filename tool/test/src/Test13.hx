// Test13 -> a_b.Exposed
// Haxe expose edge cases
import a_b.Exposed;

class Test13 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test13')));
		Bundle.load(Exposed).then(function(_) {
			new Exposed().t();
		});
	}
}
