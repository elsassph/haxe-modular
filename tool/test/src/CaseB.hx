class CaseB {
	public function new() {
		trace('CaseB');
		new DepAB();
		new DepB();
		#if uselib
		new lib.Lib.Lib2();
		#end
	}
}
