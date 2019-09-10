import haxe.DynamicAccess;

class MinifyId
{
	static var BASE_16 = 'abcdefghijklmnop'.split('');
	static var blacklist:Map<String, Bool> = ["HxOverrides" => true];

	var map:DynamicAccess<String> = {};
	var index:Int = 0;

	public function new()
	{
	}

	/**
	 * Preserve an id from minification
	 */
	public function set(id:String)
	{
		map.set(id, id);
	}

	/**
	 * return a minified id
	 */
	public function get(id:String)
	{
		if (blacklist.exists(id)) return id;
		if (id.length <= 2) return id;
		var min = map.get(id);
		if (min == null) {
			var B16 = BASE_16;
			var i = index++;
			min = '';
			while (i > 0xf) {
				var add = i & 0xf;
				i = (i >> 4) - 1;
				min = B16[add] + min;
			}
			min = B16[i] + min;
			map.set(id, min);
		}
		return min;
	}
}
