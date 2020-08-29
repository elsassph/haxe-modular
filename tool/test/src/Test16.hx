// Test16 -> empty lib
// Haxe 4 HxOverrides

class Test16 {
	static function main() {
		trace('Suite Test16');

		Bundle.loadLib('lib', ['foo']).then(function(_) {
			trace('Lib loaded. Stamp = ${haxe.Timer.stamp()}');
		});
	}
}
