# NPM dependencies bundling

If you use NPM libraries, it is required to follow a certain pattern and bundle them in
a separate JavaScript file.

It is nicely in line with the best practice (for compilation speed and better caching)
that recommends regrouping all the NPM dependencies into a single JavaScript file,
traditionally called `vendor.js` or `libs.js`.

**Important:**
- this is necessary for the browser only,
- never run Browserify on the Haxe Modular generated JS files.

## Template

A very specific structure has to be followed.

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
		// enable React hot-reload (optional)
		require('haxe-modular');
	}

})(typeof $hx_scope != "undefined" ? $hx_scope : $hx_scope = {});
```

### Explanations

It hopefully is understandable that we are defining a "registry" of NPM modules.

In the browser we will have a global object `window.$hx_scope.__registry__` used by
Modular to resolve NPM modules.

It is important to correctly name the keys of the object (eg. `'react'`) to match the
Haxe require calls (eg. `@:jsRequire('react')`).

Inside the `if (process.env.NODE_ENV !== 'production')` case you can invoke libraries
only for debug mode. Here for example it includes the hot-module replacement logic which
will be removed in production.

**Tip:** there is nothing forcing your to register NPM modules, you can register any
valid JavaScript object here!

## Building

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
  `NODE_ENV` variable on Windows. Alternatively you can use Browserify's `envify`.

## Usage

Once you have created this library, it MUST be loaded before your Haxe code referencing
them is loaded.

Simply reference the library file in your `index.html` in the right order:

```html
<script src="libs.js"></script>
<script src="index.js"></script>
```

You can create other libraries, and even use the same lazy loading method to load them
on demand, just like you will load Haxe modules. If you have a Haxe module with its
own NPM dependencies, you will load the dependencies first, then the Haxe module.
