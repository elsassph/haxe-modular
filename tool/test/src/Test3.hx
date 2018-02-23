class Test3 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test3')));
		new DepMain();
		Bundle.load(CaseC).then(function(_) new CaseC() );
	}
}
