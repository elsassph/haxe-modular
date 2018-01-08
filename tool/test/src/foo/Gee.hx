package foo;

class Gee extends Shared
{
	public function new()
	{
		super();
		trace('4. new Gee');
		share('Gee');
		Bundle.load(Moo).then(function(_) {
			var m = new Moo();
		});
	}

}