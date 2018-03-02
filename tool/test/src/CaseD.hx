class CaseD {
	static public var cyclic:Bool;

	static public function init() {
		trace('CaseC');
		CycleD.init();
	}
}

class CycleD {
	static public function init() {
		trace('CycleD');
		CaseD.cyclic = true;
	}
}