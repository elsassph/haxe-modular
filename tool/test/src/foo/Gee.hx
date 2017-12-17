package foo;

class Gee
{
	public function new()
	{
		trace('4. new Gee');
		Bundle.load(Moo).then(function(_) {
			var m = new Moo();
		});
	}

}