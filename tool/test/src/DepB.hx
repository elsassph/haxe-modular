class DepB {
	public function new() {
		trace('DepB');
		var a = DepDepB.A;
	}
}

enum DepDepB {
	A;
	B;
}