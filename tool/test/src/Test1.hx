class Test1 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test1')));
		Bundle.load(CaseA).then(function(_) new CaseA() );
		Bundle.load(CaseB).then(function(_) new CaseB() );
	}
}
