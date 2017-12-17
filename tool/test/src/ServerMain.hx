package;

import foo.Bar;

class ServerMain
{
    static public function main()
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

        var route = RouteBundle.load(Bar);
    }
}