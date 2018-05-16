// Test11 -> CaseF
// Static __init__
class Test11 {
	static function main() {
		trace('Suite ' + Type.getClassName(Type.resolveClass('Test11')));
		Bundle.load(CaseF).then(function(_) new CaseF());
	}
}
