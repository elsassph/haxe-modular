class SubC2 {
	public function new() {
		trace('SubC2');
		new SubC.DepSubC();
	}
}
