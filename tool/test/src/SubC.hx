class SubC {
	public function new() {
		trace('SubC');
		new DepSubC();
	}
}

class DepSubC {
	public function new() {
		trace('DepSubC');
		new DepMain();
	}
}
