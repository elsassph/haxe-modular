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

    Using regular Haxe compiler options and metadata it is possible to emit multiple
    JavaScript files from a single codebase. These files only need a minor post-generation 
    treatment in order to behave at runtime like a single script. 

3. Lazy loading

    A helper class allows to easily load modules at runtime. Modularisation is not
    automatic but user-defined.

4. Hot-reload

    The same helper class can be used listen to a LiveReload server and reload
    lazy-loaded modules automatically.


This project provides support classes to implement the proposed solution:

    haxelib install modular


## NPM dependencies bundling

Best practice (for speed and better caching) is to regroup all the NPM dependencies
into a single JavaScript file, traditionally called `vendor.js` or `libs.js`.

It is good (and quite complicated) in JavaScript, when using Webpack or others, because 
it significantly improves build times, and gives you a nicely cacheable file. 

It is required (and very easy) when doing a modular Haxe application, because this is 
needed to share NPM dependencies between Haxe modules. *In fact, you should use this 
technique for non-modular applications as well!*

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
})(typeof $hx_scope != "undefined" ? $hx_scope : $hx_scope = {});
```

As you can see we are defining a "registry" of NPM modules. It is very important to 
correctly name the keys of the object (eg. `'react'`) to match the Haxe require 
calls (eg. `@:jsRequire('react')`). 

`$hx_scope` is the "scope root" of this modularity system. Generated Haxe JavaScript 
files will look up required modules from `$hx_scope.__registry__`.

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

Simply reference the library file in your `index.html`. Smart browers will even be able 
to load the scripts in parallel:

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

For code splitting we are going to use 2 Haxe-JS compiler features:

1. [Exclude package](http://api.haxe.org/haxe/macro/Compiler.html#exclude) 
   compiler flag: `--exclude('name.of.package')`

   This is very important because we will essentially compile the application several
   times, excluding what should not be in each module.

2. [Exposing Haxe classes for JavaScript](https://haxe.org/manual/target-javascript-expose.html) 
   using the class `@:expose` metadata. 

   This is the key to "joining" the modules: lazy-loaded and shared classes have to be 
   "exposed" in order to be usable from other modules.

### Using exclusion

Planning starts here:
- what modules will I need to create?
- what will be their entry point?
- what should be excluded in each module?
- which classes will be shared?

#### What modules will I need to create?

For example if you architect a React+Redux application, you will at least split it into:
- core (startup, Redux store setup, ReactDOM render),
- views (React views, thunk async operations).

*Separating the views is the minimum structure because we'll want to hot-reload them.*

#### What will be their entry point?

For the "core" module: the Main class is the obvious entry point.

For the "views" module: we will reference each top-level React view.

#### What should be excluded in each module?

Exclusion is easier if you exclude entire packages, which means you will want to
organise your classes by module and give them a specific package name:
for instance `myapp.core` and `myapp.view`:

To compile the core module, `-main Main` marks the executable entry point.

    # index.hxml
    -lib modular
    -lib react
    -src src
    -js bin/index.js
    -main Main
    --macro exclude('myapp.view')
    --macro Stub.modules()

To compile the views module, `myapp.view.MyAppView` marks a top-level view. You can 
reference other top-level classes which could be referenced from the core module.
In this example `myapp.core` is excluded but you only need to do it if you actually 
reference core classes in the views.

    # view.hxml
    -lib modular
    -lib react
    -src src
    -js bin/view.js
    myapp.view.MyAppView
    --macro exclude('myapp.core')
    --macro Stub.modules()

**Important:** all modules, including the main one, must have `--macro Stub.modules()`
in their compiler arguments. This is the modules post-processor.

### Which classes will be shared?

Now the tricky part: the different modules will need to access classes from other 
modules, that is, they need to be "shared". For example the core module will need to
reference `myapp.view.MyAppView` to render the application.

Normally, you must explicitly add `@:expose` in front of each and every shared class:

```haxe
@:expose
class MyAppView extends ReactComponent {
    ...
}
```

To facilitate this process, `Stub.modules` can accept a parameter which would be a
list of packages to automatically expose:

    --macro Stub.modules(['myapp.model','myapp.command'])

**Important**: unfortunately Haxe Enums can NOT be exposed/shared, but they can be excluded
(which will break your code), so you must make sure Enums are never in an excluded 
package if you need to use them (eg. creating Enum values) in in multiple modules. 
You probably should declare Enums in their own `myapp.enums` package.


## Lazy loading

The `Require` class provides Promise-based lazy-loading functionality:

```haxe
import myapp.view.MyAppView;
...
Require.module('view').then(function(_) {
    // 'view.js' was loaded and evaluated.
    // Class myapp.view.MyAppView can be safely used from now on.
    // It's time to render the view.
    new MyAppView();
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

### LiveReload server

The feature is based on the [LiveReload](https://livereload.com) API. `Require` will 
set a listener for `LiveReloadConnect` and register a "reloader plugin" to handle changes. 

It is recommended to simply use [livereloadx](https://livereloadx). The static mode 
dynamically injects the livereload client API script in HTML pages served:

    npm install livereloadx -g
    livereloadx -s bin
    open http://localhost:35729

The reloader plugin will prevent page reloading when JS files change, and if the JS file 
corresponds to a lazy-loaded module, it is reloaded and re-evaluated.

The feature is simply based on filesystem changes, so you just have to rebuild the 
Haxe-JS application and let LiveReload inform our running application to reload some of 
the JavaScript files.

PS: stylesheets and static images will be normally live reloaded.
