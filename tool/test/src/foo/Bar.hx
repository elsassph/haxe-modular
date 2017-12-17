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
	}

	public function hello()
	{
		trace('hello');
	}
}