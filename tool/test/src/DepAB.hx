class DepAB {
	public function new() {
		trace('DepAB');
		new DepDepAB();
	}
}

class DepDepAB {
	public function new() {
		trace('DepDepAB');
	}
}