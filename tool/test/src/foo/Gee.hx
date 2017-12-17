package foo;

class Gee
{
	public function new()
	{
		trace('Gee');
		Bundle.load(Moo).then(function(_) {
			var m = new Moo();
		});
	}

}