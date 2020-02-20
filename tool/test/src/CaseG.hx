class CaseG {
	public function new() {
		trace('CaseG');
		var a = [1,2,3];
        Lambda.foreach(a, function(it) { trace(it); return true; });
    }
}
