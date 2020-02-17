package;

import haxe.DynamicAccess;
import haxe.Json;
import js.Node;
import js.node.Fs;
import js.node.Path;

typedef PackageStat = {
	size:Int,
	?rel:Float,
	?group:DynamicAccess<PackageStat>
}

class Reporter
{
	final stats:DynamicAccess<PackageStat>;
	final enabled:Bool;
	var current:PackageStat;

	public function new(enabled:Bool)
	{
		this.enabled = enabled;
		stats = {};
	}

	public function save(output:String)
	{
		if (!this.enabled) return;
		trace('Size report: ${output}.stats.json');
		calculate_rec(stats);
		final raw = Json.stringify(stats, null, '  ');
		Fs.writeFileSync(output + '.stats.json', raw);

		final src = Fs.readFileSync(Path.join(Node.__dirname, 'viewer.js'), 'utf8');
		final viewer = '<!DOCTYPE html><body><script>var __STATS__ = $raw;\n$src</script></body>';
		Fs.writeFileSync(output + '.stats.html', viewer);
	}

	function calculate_rec(group:DynamicAccess<PackageStat>)
	{
		var total = 0;
		for (key in group.keys()) {
			total += group.get(key).size;
		}
		for (key in group.keys()) {
			final node = group.get(key);
			node.rel = Math.round(1000 * node.size / total) / 10;
			if (node.group != null) calculate_rec(node.group);
		}
	}

	public function includedBefore(size:Int)
	{
		if (!enabled || size < 50) return;
		current.size += size;
		current.group.set('INCLUDE', {
			size:size, rel:0
		});
	}

	public function start(bundle:Extractor.Bundle)
	{
		if (!enabled) return;
		current = {
			size:0,
			rel:0,
			group:{}
		};
		stats.set(bundle.name + '.js', current);
	}

	public function add(tag:String, size:Int)
	{
		if (!enabled) return;
		current.size += size;
		if (tag == null || tag == '__reserved__' || tag.charAt(0) == '$') return;
		final parts = tag.indexOf("_$") < 0 ? tag.split('_') : safeSplit(tag);
		if (parts.length == 1) parts.unshift('TOPLEVEL');
		var parent = current;
		for (p in parts) {
			if (parent.group == null) parent.group = {};
			var node = parent.group.get(p);
			if (node == null) {
				node = { size:0, rel:0 };
				parent.group.set(p, node);
			}
			node.size += size;
			parent = node;
		}
	}

	function safeSplit(tag:String)
	{
		final p = [];
		var acc = '';
		for (i in 0...tag.length) {
			final c = tag.charAt(i);
			if (c != '_') {
				if (c != '$' || tag.charAt(i - 1) != '_') acc += c;
			}
			else if (tag.charAt(i + 1) != '$') {
				p.push(acc);
				acc = '';
			}
			else acc += '_';
		}
		p.push(acc);
		return p;
	}
}
