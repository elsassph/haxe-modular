package;

import foo.Bar;
import js.Browser;

class Main extends Shared
{
	static function main()
	{
		new Main();
	}

	public function new()
	{
		super();
		trace('new Main');
		share('Main');
		trace(Type.resolveClass('Keeped') != null ? '(has Keeped)' : '(uh oh, Keeped is missing)');

		var body = Browser.document.body;
		body.onclick = click;

		Bundle.load(Unused).then(function(_) {
			trace('Not doing anything concrete with it');
		});
	}

	function click(_)
	{
		trace('click');
		Bundle.load(Bar).then(function(_) {
			var b = new Bar();
			b.hello();
			Bundle.load(Bar).then(function(_) {
				trace('still ok');
			});
		});
	}
}

@:keep
class Keeped
{
	public function new()
	{
		trace('This class needs to be kept');
	}
}
