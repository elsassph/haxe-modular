package;

import foo.Gee;
import foo.Sub__M;

@:keep
class Unused
{
	public function new()
	{
		trace('I\'m not used');

		Bundle.load(Sub__M).then(function(_) {
			var s = new Sub__M();
		});

		var g = new Gee();
	}
}
