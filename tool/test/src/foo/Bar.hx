package foo;

import js.html.DataView;

class Bar
{
	public function new()
	{
		trace('new Bar');
		var d = 4;
		var c = [1, 2, 3];
		c.push(d);

		var d = new DataView(null);

		Bundle.load(Sub).then(function(_) {
			var s = new Sub();
		});

		var g = new Gee();
	}

	public function hello()
	{
		trace('hello');
	}
}