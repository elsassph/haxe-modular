package;

import foo.Bar;
import js.Browser;

class Main
{
	static function main()
	{
		new Main();
	}

	public function new()
	{
		trace('new Main');
		var body = Browser.document.body;
		body.onclick = click;
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