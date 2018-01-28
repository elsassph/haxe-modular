class DepMain {
	public function new() {
		trace('DepMain');
		new DepDepMain();
	}
}

class DepDepMain {
	public function new() {
		trace('DepDepMain');
	}
}