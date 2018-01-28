class CaseC {
	public function new() {
		trace('CaseC');
		Bundle.load(DepC).then(function(_) new DepC() );
	}
}
