// TestInterop -> CaseInterop
// CaseInterop uses HTML compat classes
class TestInterop {
	static function main() {
		var i = cast(0, Int);
		var t = Date.now();
		Bundle.load(CaseInterop).then(function(_) new CaseInterop() );
	}
}
