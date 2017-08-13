var createProxy = require('react-proxy').default;
var deepForceUpdate = require('react-deep-force-update');
var React = require('react');

/* COMPONENT PROXY */

var proxies = {};

function register(classRef, name, file)
{
	if (classRef == null || name == null || file == null) return;
	var key = name + '@' + file;
	if (proxies[key]) {
		classRef.__hx_proxy__ = key;
		classRef.displayName = name;
		proxies[key].update(classRef);
	}
	else {
		classRef.__hx_proxy__ = key;
		classRef.displayName = name;
	}
}

function refresh(rootElement)
{
	deepForceUpdate(rootElement);
}

/* REACT OVERRIDE */

var _createElement = React.createElement;

React.createElement = function(type) {
	if (type && type.__hx_proxy__) {
		var proxy = proxies[type.__hx_proxy__];
		if (!proxy) proxy = proxies[type.__hx_proxy__] = createProxy(type);
		var args = Array.prototype.slice.call(arguments, 1);
		args.unshift(proxy.get());
		return _createElement.apply(React, args);
	}

	return _createElement.apply(React, arguments);
}

module.exports = { register: register, refresh: refresh };

if (!window.__REACT_HOT_LOADER__)
	window.__REACT_HOT_LOADER__ = module.exports;
