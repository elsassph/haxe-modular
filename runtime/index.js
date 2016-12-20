var createProxy = require('react-proxy').default;
var deepForceUpdate = require('react-deep-force-update');
var React = require('react');

/* COMPONENT PROXY */

var proxies = {};

function register(classRef, name, file) 
{
	if (proxies[file]) {
		classRef.__proxy__ = file;
		classRef.displayName = name;
		proxies[file].update(classRef);
	}
	else {
		classRef.__proxy__ = file;
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
	if (type.__proxy__) {
		var proxy = proxies[type.__proxy__];
		if (!proxy) proxy = proxies[type.__proxy__] = createProxy(type);
		var args = Array.prototype.slice.call(arguments, 1);
		args.unshift(proxy.get());
		return _createElement.apply(React, args);
	}
	
	return _createElement.apply(React, arguments);
}

if (!window.__REACT_HOT_LOADER__) 
	window.__REACT_HOT_LOADER__ = { register: register, refresh: refresh };
