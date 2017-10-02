# Modular Haxe-JS

Code splitting and hot-reload for Haxe-JS applications.

*Haxe modular is a set of tools and support classes allowing Webpack-like code-splitting,
lazy loading and hot code reloading. Without Webpack and the JS fatigue.*

For complete architecture examples using this technique you can consult:

- [Haxe React+Redux sample](https://github.com/elsassph/haxe-react-redux)
- [Haxe React+MMVC sample](https://github.com/elsassph/haxe-react-mmvc)

Notes:
- There is in fact also a [webpack-haxe-loader](https://github.com/jasononeil/webpack-haxe-loader),
based on this library.
- Do not confuse with [modular-js](https://github.com/explorigin/modular-js/network),
which has a similar general goal but a different approach based on emitting one JS file
per Haxe class (check the forks).

> This project is compatible with Haxe 3.2.1+

## Context

JavaScript is one of the target platforms of
[Haxe](http://haxe.org/documentation/introduction/language-introduction.html),
a mature, strictly typed, high level, programming language offering a powerful type system
and FP language features. The compiler stays very fast, even with massive codebases.

If anything, *optimised bundling* is exactly was Haxe does best: Haxe offers out of the
box incomparable dead-code elimination and generates very efficient JavaScript.

What Haxe lacks natively is *code splitting and HMR*. Haxe doesn't suggest any best
practice to implement it.

The goal of this project is to propose one robust and scalable solution.

## Overview of solution

1. NPM dependencies bundling in a single libs/vendor JavaScript file

	Best practice (for speed and better caching) is to regroup all the NPM dependencies
	into a single JavaScript file, traditionally called `vendor.js` or `libs.js`.

2. Haxe-JS code and source-maps splitting, and lazy-loading

	Code splitting works by identifying features which can be asynchronously loaded at
	run time. JS bundles can be created automatically by using the `Bundle.load` helper.

4. Hot-reload

	A helper class can be used listen to a LiveReload server and reload lazy-loaded
	modules automatically.


## Installation

You need to install both a Haxe library and a NPM module:

	# code splitting and hot-reload
	npm install haxe-modular --save

	# Haxe support classes
	haxelib install modular

Add to your HXML:

	# Haxe support classes and output rewriting
	-lib modular


## NPM dependencies bundling

Best practice (for compilation speed and better caching) is to regroup all the NPM
dependencies into a single JavaScript file, traditionally called `vendor.js` or `libs.js`.

It is absolutely required when doing a modular Haxe application sharing NPM modules,
and in particular if you want to use the React hot-reload functionality.

### Template

Create a `src/libs.js` file using the following template:

```javascript
//
// npm dependencies library
//
(function(scope) {
	'use-strict';
	scope.__registry__ = Object.assign({}, scope.__registry__, {
		//
		// list npm modules required in Haxe
		//
		'react': require('react'),
		'react-dom': require('react-dom'),
		'redux': require('redux')
	});

	if (process.env.NODE_ENV !== 'production') {
		// enable React hot-reload
		require('haxe-modular');
	}

})(typeof $hx_scope != "undefined" ? $hx_scope : $hx_scope = {});
```

It hopefully is understandable that we are defining a "registry" of NPM modules.
In the browser we will have a global object `window.$hx_scope.__registry__` used by
Modular to resolve NPM modules.

It is important to correctly name the keys of the object (eg. `'react'`) to match the
Haxe require calls (eg. `@:jsRequire('react')`).

For React hot-module replacement, you just have to `require('haxe-modular')`. Notice
that this enablement is only for development mode and will be removed when doing a
release build.

Tip: there is nothing forcing your to register NPM modules, you can register any
valid JavaScript object here.

### Building

The library must be "compiled", that is required modules should be injected,
typically using [Browserify](http://browserify.org/) (small, simple, and fast).

For development (code with sourcemaps):

	browserify src/libs.js -o bin/libs.js -d

For release, optimise and minify:

	cross-env NODE_ENV=production browserify src/libs.js | uglifyjs -c -m > bin/libs.js

The difference is significant: React+Redux goes from 1.8Mb for dev to 280Kb for release
(and 65Kb with `gzip -6`).

Note:
- `NODE_ENV=production` will tell UglifyJS to remove "development" code from modules,
- `-d` to make source-maps, `-c` to compress, and `-m` to "mangle" (rename variables),
- [cross-env](https://www.npmjs.com/package/cross-env) is needed to be able to set the
  `NODE_ENV` variable on Windows. Alternatively you can use `envify`.

### Usage

If you use NPM libraries (like React and its multiple addons), you will want to create
at least one library. The library MUST be loaded before your Haxe code referencing
them is loaded.

Simply reference the library file in your `index.html` in the right order:

```html
<script src="libs.js"></script>
<script src="index.js"></script>
```

You can create other libraries, and even use the same [lazy loading](#lazy-loading) method
to load them on demand, just like you will load Haxe modules. If you have a Haxe module
with its own NPM dependencies, you will load the dependencies first, then the Haxe module.

**Important:**
- all the NPM dependencies have to be moved into these NPM bundles,
- do not run Browserify on the Haxe-JS files!


## Haxe-JS code splitting

Code splitting requires a bit more planning than in JavaScript, so **read carefully**!

Features need to have one entry point class that can be loaded asynchronously.

A good way to split is to break down your application into "routes" (cf.
[react-router](https://github.com/ReactTraining/react-router/tree/master/docs)) or
reusable complex components.

### How it works

- A graph of the classes "direct references" is created,
- The references graph is split at the entry point of bundles,
- Each bundle will include the direct (non-split) graph of classes,
- unless the class is present in the main bundle (it will be shared).

What is a direct reference?
- `new A()`
- `A.b` / `A.c()`
- `Std.is(o, A)`
- `cast(o, A)`
- ...

#### Difference between Debug and Release builds

Debug builds are optimised for "hot-reload":

- Enums are compiled in the main bundle, otherwise you may load several incompatible
  instances of the enum definitions.
- Transitive dependencies will be duplicated (eg. sub-components of views may be
  included in several routes) so you can hot-reload these sub-components.

Release builds are optimised for size:

- All classes (and their dependencies) used in more than one bundle will be included
  in the main bundle.

## Bundling

The `Bundle` class provides the module extraction functionality which then translates into
the regular "Lazy loading" API.

```haxe
import myapp.view.MyAppView;
...
Bundle.load(MyAppView).then(function(_) {
	// Class myapp.view.MyAppView can be safely used from now on.
	// It's time to render the view.
	new MyAppView();
});
```

### API

`Bundle.load(module:Class, loadCss:Bool = false):Promise<String>`

- `module`: the entry point class reference,
- `loadCss`: optionally load a CSS file of the same name.
- returns a Promise providing the name of the loaded module

(API is identical generally to the "Lazy loading" feature below)

### React-router usage

`Bundle.loadRoute(MyAppView)` generates a wrapper function to satisfy React-router's
async routes API using [getComponent](https://github.com/ReactTraining/react-router/blob/master/docs/API.md#getcomponentnextstate-callback):

```js
<Route getComponent=${Bundle.loadRoute(MyAppView)} />
```

Magic! `MyAppView` will be extracted in its own bundle and loaded lazily when the
route is activated.


## Lazy loading

The `Require` class provides Promise-based lazy-loading functionality for JS files:

```haxe
Require.module('view').then(function(_) {
	// 'view.js' was loaded and evaluated.
});
```

`Require.module` returns the same Promise for a same module unless it failed,
otherwise, calling the function again will attempt to reload the failed script.

### API

`Require.module(module:String, loadCss:Bool = false):Promise<String>`

- `module`: the name of the JS file to load (Haxe-JS module or library),
- `loadCss`: optionally load a CSS file of the same name.
- returns a Promise providing the name of the loaded module

`Require.jsPath`: relative path to JS files (defaults to `./`)

`Require.cssPath`: relative path to CSS files (defaults to `./`)


## Hot-reload

Hot-reload functionality is based on the lazy-loading feature.

Calling `Require.hot` will set up a LiveReload hook. When a JS file loaded using
`Require.module` will change, it will be automatically reloaded and the callbacks will
be triggered to allow the application to handle the change.

```haxe
#if debug
Require.hot(function(_) {
	// Some lazy-loaded module has been reloaded (eg. 'view.js').
	// Class myapp.view.MyAppView reference has now been updated,
	// and new instances will use the newly loaded code!
	// It's time to re-render the view.
	new MyAppView();
});
#end
```

**Important**: hot-reload does NOT update code in existing instances - you must create new
instances of reloaded classes to use the new code.

### API

`Require.hot(?handler:String -> Void, ?forModule:String):Void`

- `handler`: a callback to be notified of modules having reloaded
- `forModule`: if provided, only be notified of a specific module changes

### React hot-reload wrapper

When using hot-reload for React views you will want to use the handy `autoRefresh` wrapper:

```haxe
var app = ReactDOM.render(...);

#if (debug && react_hot)
ReactHMR.autoRefresh(app);
#end
```

The feature leverages [react-proxy](https://github.com/gaearon/react-proxy/tree/master) and
needs to be enabled by calling `require('haxe-modular')`, preferably in your NPM modules bundle.

Note: you must compile with `-D react_hot`. The feature is only enabled in `debug` mode.

### LiveReload server

The feature is based on the [LiveReload](https://livereload.com) API. `Require` will
set a listener for `LiveReloadConnect` and register a "reloader plugin" to handle changes.

It is recommended to simply use [livereloadx](http://nitoyon.github.io/livereloadx/). The
static mode dynamically injects the livereload client API script in HTML pages served:

	npm install livereloadx -g
	livereloadx -s bin
	open http://localhost:35729

The reloader plugin will prevent page reloading when JS files change, and if the JS file
corresponds to a lazy-loaded module, it is reloaded and re-evaluated.

The feature is simply based on filesystem changes, so you just have to rebuild the
Haxe-JS application and let LiveReload inform our running application to reload some of
the JavaScript files.

PS: stylesheets and static images will be normally live reloaded.

## Known issues

### Problem with init

If you don't know what `__init__` is, don't worry :)
[If your're curious](http://old.haxe.org/doc/advanced/magic#initialization-magic)

When using `__init__` you may generate code that will not be moved to the right bundle:

- assume that `__init__` code will be duplicated in all the bundles,
- unless you generate calls to static methods.

```haxe
class MyComponent
{
	static function __init__()
	{
		// these lines will go in all the bundles
		var foo = 42;
		untyped window.something = function() {...}

		// these lines will go in the bundle containing MyComponent
		MyComponent.doSomething();
		if (...) MyComponent.anotherThing();

		// this line will go in the bundle containing OtherComponent
		OtherComponent.someProp = 42;
	}
	...
}
```

## Further troubleshooting

Modular recognises a few additional debugging flags:

- `-D modular_dump`: generate an additional `.graph` file showing the relationship
  between classes,
- `-D modular_debugmap`: generate, for each module, an additiona; `.map.html` file
  showing a visual representation of the sourcemap.
