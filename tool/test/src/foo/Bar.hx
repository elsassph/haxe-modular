package foo;

import js.html.DataView;

class Bar
{
	public function new()
	{
		trace('3. new Bar');
		var d = 4;
		var c = [1, 2, 3];
		c.push(d);

		Bundle.load(Sub).then(function(_) {
			var s = new Sub();
		});

		var g = new Gee();
	}

	public function hello()
	{
		trace('5. Bar hello');
		#if !nodejs
		var d = new DataView(null);
		#end
	}
}