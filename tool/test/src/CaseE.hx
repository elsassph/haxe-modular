class CaseE {
	static public var SECRET = 'secret';
	public function new() {
		trace('CaseE');
		trace(Test10.SECRET);
		Bundle.load(DepE).then(function(_) new DepE() );
	}
}
