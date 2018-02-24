package;

import haxe.DynamicAccess;
import haxe.Timer;
import js.Browser.window;
import js.Browser.document;
import js.html.DivElement;
import js.html.KeyboardEvent;
import js.html.MouseEvent;
import js.html.PopStateEvent;

typedef PackageStat = {
	size:Int,
	?rel:Float,
	?group:DynamicAccess<PackageStat>
}

typedef CarrotSearchFoamTreeGroup = {
	label:String,
	weight:Float,
	size:Int,
	?open:Bool,
	?exposed:Bool,
	?selected:Bool,
	?parent:CarrotSearchFoamTreeGroup,
	?attribution:Dynamic,
	?groups:Array<CarrotSearchFoamTreeGroup>
}

typedef CarrotSearchFoamTreeEvent = {
	type:String,
	altKey:Bool,
	ctrlKey:Bool,
	shiftKey:Bool,
	metaKey:Bool,
	secondary:Bool,
	delta:Int,
	scale:Float,
	touches:Int,
	topmostClosedGroup:CarrotSearchFoamTreeGroup,
	group:CarrotSearchFoamTreeGroup,
	preventDefault:Void->Void,
	preventOriginalEventDefault:Void->Void,
	x:Int,
	xAbsolute:Int,
	y:Int,
	yAbsolute:Int,
}

extern class CarrotSearchFoamTree {
	public function new(options:Dynamic);
	public function zoom(group:CarrotSearchFoamTreeGroup):Void;
	public function get(property:String):Dynamic;
	public function set(property:String, value:Dynamic):Void;
	public function resize():Void;
}

class StatsViewer
{
	static inline var MAX_DEPTH = 3;

	var allGroups:Array<CarrotSearchFoamTreeGroup>;
	var filtered:Array<CarrotSearchFoamTreeGroup> = [];
	var pendingFilter:Bool;
	var pendingGroup:CarrotSearchFoamTreeGroup;
	var totalSize:Int;

	var tip:DivElement;
	var tipWidth:Int;
	var tipHeight:Int;
	var delayResize:Timer;
	var delayClick:Timer;

	var foamtree:CarrotSearchFoamTree;

	static function main()
	{
		var app = new StatsViewer();
	}

	public function new()
	{
		var stats = getStats();
		allGroups = formatData(stats);

		var element = createElement();
		tip = createTip();
		tipWidth = 0;
		tipHeight = 0;
		foamtree = createFoamTree(element, allGroups);
		addEventListener();
	}

	function addEventListener()
	{
		window.addEventListener('resize', function(_) {
			if (delayResize != null) return;
			delayResize = Timer.delay(function() {
				delayResize = null;
				foamtree.resize();
			}, 300);
		});
		window.addEventListener('mousemove', function(e:MouseEvent) {
			if (e.pageX < window.innerWidth - 240)
				tip.style.left = (e.pageX) + 'px';
			else
				tip.style.left = (e.pageX - tipWidth) + 'px';
			if (e.pageY < window.innerHeight - 140)
				tip.style.top = (e.pageY + 20) + 'px';
			else
				tip.style.top = (e.pageY - tipHeight - 5) + 'px';
		});
		document.body.addEventListener('keydown', function(e:KeyboardEvent) {
			if (e.keyCode == 27) {
				if (filtered.length > 0) {
					e.preventDefault();
					window.history.back();
				}
				else clearTip();
			}
		});
		window.addEventListener('popstate', function(e:PopStateEvent) {
			e.preventDefault();
			filtered.pop();
			var count = filtered.length;
			var groups = count > 0 ? [filtered[count - 1]] : allGroups;
			setDepth(groups);
			foamtree.set('dataObject', { groups: groups });
			clearTip();
		});
	}

	function createFoamTree(element:DivElement, groups:Array<CarrotSearchFoamTreeGroup>)
	{
		var ft = new CarrotSearchFoamTree({
			element: element,
			layout: "squarified",
			pixelRatio: window.devicePixelRatio != null ? window.devicePixelRatio : 1,
			stacking: "flattened",
			maxGroupLevelsDrawn: MAX_DEPTH,
			maxGroupLevelsAttached: MAX_DEPTH,
			maxGroupLabelLevelsDrawn: MAX_DEPTH,

			rolloutDuration: 0,
			pullbackDuration: 0,
			fadeDuration: 0,
			zoomMouseWheelDuration: 300,
			openCloseDuration: 200,

			descriptionGroupMinHeight: 40,
			groupLabelMinFontSize: 14,
			groupLabelMaxFontSize: 30,
			groupLabelVerticalPadding: 0,

			dataObject: { groups: groups },

			onGroupClick: function(event:CarrotSearchFoamTreeEvent) {
				event.preventDefault();
				pendingFilter = true;
				handleClick(event.group);
			},
			onGroupDoubleClick: function(event:CarrotSearchFoamTreeEvent) {
				event.preventDefault();
			},
			onGroupHover: function(event:CarrotSearchFoamTreeEvent) {
				if (event.group != null && event.group.attribution != null) {
					event.preventDefault();
					return;
				}
				updateTip(event);
			}
        });
		return ft;
	}

	function handleClick(group:CarrotSearchFoamTreeGroup)
	{
		if (group == null || group.attribution != null) return;
		pendingGroup = group;

		if (delayClick != null) return;
		delayClick = Timer.delay(function() {
			delayClick = null;
			if (pendingFilter) {
				pendingFilter = false;
				if (filtered.indexOf(pendingGroup) >= 0) return;
				filtered.push(pendingGroup);
				var groups = [pendingGroup];
				Timer.delay(function() {
					setDepth(groups);
					foamtree.set('dataObject', { groups: groups });
					window.history.pushState(null, pendingGroup.label);
					clearTip();
				}, 100);
			}
			else foamtree.zoom(pendingGroup);
		}, 300);
	}

	function setDepth(groups:Array<CarrotSearchFoamTreeGroup>)
	{
		var count = countChildren(groups);
		var value = MAX_DEPTH + Math.round(50 / count);
		if (foamtree.get('maxGroupLevelsAttached') != value) {
			foamtree.set('maxGroupLevelsDrawn', value);
			foamtree.set('maxGroupLevelsAttached', value);
			foamtree.set('maxGroupLabelLevelsDrawn', value);
		}
	}

	function countChildren(groups:Array<CarrotSearchFoamTreeGroup>):Int
	{
		var count = 0;
		for (g in groups) {
			count += 1 + countChildren(g.groups);
			if (count > 100) return count;
		}
		return count;
	}

	function updateTip(e:CarrotSearchFoamTreeEvent)
	{
		var o = e.group;
		if (o == null) {
			clearTip();
			return;
		}
		var label = '<b>${pathOf(o)}</b><br/> Size: ${o.size} bytes<br/>';
		if (o.parent != null) {
			if (o.parent.parent != null) label += 'Package percents: ${o.weight}%<br/>';
			label += 'Bundle percents: ${round(o.size, moduleSizeOf(o))}%<br/>';
		}
		label += 'Total percents: ${round(o.size, totalSize)}%<br/>';
		tip.innerHTML = label;
		tip.style.visibility = 'visible';
		tipWidth = tip.offsetWidth;
		tipHeight = tip.offsetHeight;
	}

	function clearTip()
	{
		tip.style.visibility = 'hidden';
		tip.innerHTML = '';
		tipWidth = tip.offsetWidth;
		tipHeight = tip.offsetHeight;
	}

	function pathOf(o:CarrotSearchFoamTreeGroup)
	{
		var label = o.label;
		if (o.parent == null) return '[${o.label}]';
		if (o.groups != null && o.groups.length > 0) label += '.*';
		while (o.parent != null) {
			o = o.parent;
			if (o.parent == null) label = '[${o.label}]<br/>$label';
			else if (o.label != 'TOPLEVEL') label = '${o.label}.$label';
		}
		return label;
	}

	function moduleSizeOf(o:CarrotSearchFoamTreeGroup)
	{
		while (o.parent != null) {
			o = o.parent;
		}
		return o.size;
	}

	function round(size:Int, total:Int)
	{
		return Math.round(1000 * size / total) / 10;
	}

	function createTip()
	{
		var div = document.createDivElement();
		div.style.position = 'absolute';
		div.style.left = '0';
		div.style.top = '0';
		div.style.width = '200px';
		div.style.padding = '4px';
		div.style.font = '12px sans-serif';
		div.style.background = '#ffe';
		div.style.border = 'solid 1px #333';
		div.style.whiteSpace = 'nowrap';
		div.style.overflow = 'hidden';
		div.style.visibility = 'hidden';
		untyped div.style['pointer-events'] = 'none';
		document.body.appendChild(div);
		return div;
	}


	function createElement()
	{
		var div = document.createDivElement();
		div.style.position = 'absolute';
		div.style.left = '0';
		div.style.top = '0';
		div.style.right = '0';
		div.style.bottom = '0';
		document.body.appendChild(div);
		return div;
	}

	function formatData(stats:DynamicAccess<PackageStat>, parent:CarrotSearchFoamTreeGroup = null)
	{
		var groups:Array<CarrotSearchFoamTreeGroup> = [];
        for (key in stats.keys()) {
          var o = stats.get(key);
          var it:CarrotSearchFoamTreeGroup = {
            label: key,
            size: o.size,
            weight: o.rel,
			open: true,
			parent: parent
          };
		  it.groups = formatData(o.group, it);
          groups.push(it);
        }
        return groups;
	}

	function getStats():DynamicAccess<PackageStat>
	{
		var stats:DynamicAccess<PackageStat> = untyped __STATS__;
		var total = 0;
        for (key in stats.keys()) {
          var o = stats.get(key);
		  total += o.size;
		}
		totalSize = total;
		return stats;
	}

}