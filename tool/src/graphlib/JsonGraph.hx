package graphlib;

@:jsRequire('graphlib', 'json')
extern class JsonGraph
{
    static public function read(json:Dynamic):Graph;
    static public function write(g:Graph):Dynamic;
}
