# Modular Haxe-JS

Code splitting and hot-reload for Haxe-JS applications.

The following approach is similar but considerably simpler than (and doesn't depend on) 
Webpack or other JSPM.

For complete examples using this technique you can consult:

- [Haxe React+Redux sample](https://github.com/elsassph/haxe-react-redux)
- [Haxe React+MMVC sample](https://github.com/elsassph/haxe-react-mmvc)

*Do not confuse with the project [modular-js](https://github.com/explorigin/modular-js), 
which has a similar general goal but uses a completely different approach.* 


## Context

### JavaScript

*Code splitting and HMR* (hot module replacement, or hot reload) is all the rage in the 
JavaScript world, lead by [Webpack](https://webpack.github.io/) as the most advanced tool. 
Webpack is however a relatively complex tool to configure, leading to the running joke
that "webpack configuration" could be a fulltime job.

The other trend is *optimised bundling*, or de-modularisation; although 
[UglifyJS](https://github.com/mishoo/UglifyJS) does a decent job at removing explicit 
dev VS production code, new and old contenders like [Rollup.js](http://rollupjs.org/)
and [Google Closure compiler](https://github.com/google/closure-compiler/wiki) 
try to go further in order to remove "dead" and unused code.

These promises, although not always compatible, are irrestible for front-end devs. 
If Haxe-JS wants to be a contender in the compile-to-JS competition, it ought to offer 
a solid answer.

### Haxe

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

2. Haxe-JS code splitting

	Code splitting works by identifying features which can be asynchronously loaded at 
	run time. Features can be automatically extracted into JS bundles. 

3. Lazy loading

	A helper class allows to easily load modules at run time. JS bundles can be created
	automatically if you use `Bundle.load`.

4. Hot-reload

	A helper class can be used listen to a LiveReload server and reload lazy-loaded 
	modules automatically.


## Installation

You need to install both a Haxe library and a NPM module: 

	# code splitting and hot-reload (must be local)
	npm install haxe-modular --save

	# Haxe support classes
	haxelib install modular

Add to your HXML:

	# Haxe support classes and output rewriting
	-lib modular


## NPM dependencies bundling

Best practice (for compilation speed and better caching) is to regroup all the NPM 
dependencies into a single JavaScript file, traditionally called `vendor.js` or `libs.js`.

It is absolutely required when doing a modular Haxe application and in particular
if you want to use the React live-reload functionality. 

### Template

Create a `src/libs.js` file using the following template:

```haxe
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

As you can see we are defining a "registry" of NPM modules. It is very important to 
correctly name the keys of the object (eg. `'react'`) to match the Haxe require 
calls (eg. `@:jsRequire('react')`). 

For React hot-module replacement, you just have to `require('haxe-modular')`. Notice 
that this enablement is only for development mode and will be removed when doing a
release build.

Note: there is nothing forcing your to register NPM modules, you can register any 
valid JavaScript object here.

### Building

The library must be "compiled", that is required modules should be injected, 
typically using [Browserify](http://browserify.org/) (very simple, and fast).

For development (code with sourcemaps):

	cross-env NODE_ENV=development browserify src/libs.js -o bin/libs.js -d

For release, optimise and minify:

	cross-env NODE_ENV=production browserify src/libs.js | uglifyjs -c > bin/libs.js

The difference is significant: React+Redux goes from 1.8Mb for dev to 280Kb for release 
(and 65Kb with `gzip -6`). 

Note:
- `NODE_ENV=production` will tell UglifyJS to remove "development" code from modules,
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
- do not run Browserify on the Haxe-JS bundles!


## Haxe-JS code splitting

Code splitting requires a bit more planning than in JavaScript, so **read carefully**! 

By splitting it means that:
- you need to break down the features of your application in units that can be logically 
  loaded at run time,
- features need to have one entry point class.

A good way to split is to break down your application into "routes" (cf. 
[react-router](https://github.com/ReactTraining/react-router/tree/master/docs)) or
reusable complex components. Don't worry too much about having a bit of redundancy.

How it works:
- A graph of the classes "direct references" is created,
- The references graph is split at the entry point of bundles,
- Each bundle will include the direct (non-split) graph of classes,
- unless the class is present in the main bundle (it will be shared).

What is a direct reference?
- `new A()`
- `A.b` / `A.c()`
- `Std.is(o, A)`

You will then want to minimize the dependencies between the bundles:
- feature bundles can load other feature bundles and use their entry point class,
- BUT feature bundles can't reference other classes from other feature bundles: 
  classes will be duplicated. 


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

This marks MyAppView as a split point, and is approximately generated into:
```haxe
Require.module('MyAppView').then(function(_) {
	// 'MyAppView.js' was loaded and evaluated.
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
