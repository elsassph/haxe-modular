package a_b;

@:expose
class Exposed {
    public function new() {}
    @:expose
    public function t() {
        trace('exposed');
        new SubExposed();
    }
}

@:expose
class SubExposed {
    public function new() {
        trace('subexposed');
    }
}
