class DepC {
	public function new() {
		trace('DepC');
		Bundle.load(SubC).then(function(_) new SubC());
		Bundle.load(SubC2).then(function(_) new SubC2());
	}
}
