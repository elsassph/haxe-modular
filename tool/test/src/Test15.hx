// Test15 -> CaseG
// Haxe 4 lambda

class Test15 {
	static function main() {
		trace('Suite Test15');
		var a = [1,2,3];
        Lambda.foreach(a, function(it) { trace(it); return true; });

		Bundle.load(CaseG).then(function(_) {
			new CaseG();
		});
	}
}
