
# Haxe Modular library

Code splitting requires a different planning than in JavaScript, so **read carefully**!

## Installation

You need to install **both** a Haxe library and a NPM module:

	# code splitting and hot-reload
	npm install haxe-modular --save

	# Haxe support classes
	haxelib install modular

Add to your HXML:

	# Haxe support classes and output rewriting
	-lib modular

By default, sourcemaps are split, but this process is quite intensive and can be disabled:

	# disable sourcemaps output
	-D modular_nomaps


## Features splitting

Code splitting is not about extracting a single class or an entire package / library.

Just like Haxe applications have a main entry point, Haxe Modular allows to split
features based on their entry point.

Examples:

- a complex component,
- an entire section / route of a website,
- a set of features, like login/registration forms, through a factory class.

Features need to have one entry point class that can be loaded **asynchronously**.

## How it works

- A graph of the classes "direct references" is created,
- The references graph is split at the entry point of bundles,
- Each bundle will include the direct (non-split) graph of classes,
- unless the class is present in the main bundle (it will be shared).

What is a direct reference?

- `new A()`
- `A.b` / `A.c()`
- `Std.is(o, A)`
- `cast(o, A)`

What is NOT a direct reference?

- a function returning an object of type `A`
- `var a:A`
- `Type.resolveClass('A')`

### Difference between Debug and Release builds

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

The Haxe code will be replaced with:
```haxe
// load 'MyAppView.js'
Require.module('MyAppView').then(function(_) {
	// Class myapp.view.MyAppView can be safely used from now on.
	// It's time to render the view.
	new MyAppView();
});
```

And after Haxe compilation, Modular's tool `haxe-split` will emit a second JS
file, `MyAppView.js`, containing the code and dependencies of `MyAppView`.

### Bundle API

`Bundle.load(module:Class):Promise<String>`

- `module`: the entry point class reference,
- returns a Promise providing the name of the loaded module

(API is identical generally to the "Lazy loading" feature below)

### React-router usage (deprecated)

`Bundle.loadRoute(MyAppView)` does the same job, but creates a wrapper function to satisfy
React-router 2 & 3 async routes API using getComponent.

```js
<Route getComponent=${Bundle.loadRoute(MyAppView)} />
```

Note: React-router 4 doesn't have any async method anymore, async routes require a new
pattern for which Modular doesn't provide helpers for at the moment.


## Lazy loading

The `Require` class provides Promise-based lazy-loading functionality for JS files:

```haxe
Require.module('script').then(function(_) {
	// 'script.js' was loaded and evaluated.
});
```

`Require.module` returns the same Promise for a same module unless it failed,
otherwise, calling the function again will attempt to reload the failed script.

### API

`Require.module(module:String):Promise<String>`

- `module`: the name of the JS file to load (Haxe-JS module or library),
- returns a Promise providing the name of the loaded module

`Require.jsPath`: relative path to JS files (defaults to `./`)

## Nodejs

Nodejs is supported, and recognised when `-D nodejs` is set (e.g. when using
`-lib hxnodejs`); Modular will then emit code specifically for nodejs.

Although the Promise API stays, bundle loading happens *synchronously*; that is it completes
immediately, while in the browser it will always complete asynchronously.
