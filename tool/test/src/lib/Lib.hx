package lib;

class Lib {
    public function new() {
        trace('Lib');
        new DepLib();
        #if libusemain
        new DepMain();
        #end
    }
}

class Lib2 {
    public function new() {
        trace('Lib2');
        new DepLib();
    }
}

class DepLib {
    public function new() {
        trace('DepLib');
    }
}
