class CaseE {
	static public var SECRET = 'secret';
	static public function init() {
		trace('CaseE');
		trace(Test10.SECRET);
		Bundle.load(DepE).then(function(_) new DepE() );
	}
}
