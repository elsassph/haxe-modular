// Test14 -> a_b.Exposed
// Haxe expose edge cases (no Reflection)
import a_b.Exposed;

class Test14 {
	static function main() {
		trace('Suite Test14');
		Bundle.load(Exposed).then(function(_) {
			new Exposed().t();
		});
	}
}
