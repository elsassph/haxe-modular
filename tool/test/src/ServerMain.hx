package;

import foo.Bar;

class ServerMain
{
    static public function main()
    {
        trace('Synchronous require');
        Bundle.load(Bar).then(function(_) {
            var b = new Bar();
			b.hello();
        });
        trace('Done');

        var route = RouteBundle.load(Bar);
    }
}