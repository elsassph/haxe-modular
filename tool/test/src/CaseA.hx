class CaseA {
	public function new() {
		trace('CaseA');
		new DepAB();
		#if uselib
		new lib.Lib();
		#end
	}
}