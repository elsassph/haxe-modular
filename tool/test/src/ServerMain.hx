package;

import foo.Bar;

class ServerMain
{
	static var runner:ServerRunner;

    static public function main()
    {
		runner = new ServerRunner();
		runner.run();
	}
}

class ServerRunner extends Shared
{
	public function new()
	{
		super();
		share('ServerRunner');
	}

	public function run()
	{
        trace('1. Synchronous require');
        Bundle.load(Bar).then(function(_) {
            var b = new Bar();
			b.hello();
			Bundle.load(Bar).then(function(_) {
				trace('8. Bar again');
			});
        });
        trace('2. Done');
		trace(Type.resolveClass('Keeped') != null ? '(has Keeped)' : '(uh oh, Keeped is missing)');

        var route = RouteBundle.load(Bar);
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