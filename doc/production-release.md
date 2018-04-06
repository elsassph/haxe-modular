# Releasing to production

Now that you have introduced code splitting, you should consider a few aspects:

- Minification,
- Deployment and URLs.


## Minification

Although Haxe's generated JavaScript is reasonably efficient, it is also very friendly
to minification, so you really want to add a minification step even if your server has
gzip enabled.

Minification will easily reduce the JavaScript payload by 30 to 40%, and is perfectly
recommendable on Modular projects.

### Recommended tools

Modular has been used with 2 industry-standard tools:

- [Uglify-JS](https://github.com/mishoo/UglifyJS2) - including mangle option
- [Google Closure Compiler](https://developers.google.com/closure/) - "simple" mode

Both generally work fine and give you similar output size, but Closure is known to be
much heavier and slower, and additionally we've found rare cases of erroneous optimisation.

### Automatic minification

Although you can proceed to minify each JavaScript file yourself using your own scripts,
you can also apply the minification automatically using Haxe libraries:

- [Uglifyjs haxelib](https://github.com/markknol/hx-uglifyjs):
    - install `uglify-js` from NPM,
    - install `uglifyjs` from Haxelib,
    - add `-lib uglifyjs` to your release build.
- [Closure haxelib](https://github.com/back2dos/closure):
    - install `closure` from Haxelib (Closure is included),
    - add `-lib closure` to your release build.

These 2 libraries will be automatically piloted by Modular to apply the minification to
each bundle.

To only compress your build for release you can specify arguments in the command line:

```
# Debug build
haxe build.hxml -debug

# Release build
haxe build.hxml -lib uglifyjs
haxe build.hxml -lib closure
```

## Deployment and URLs

Each JavaScript bundle is loaded as a file, using a `<script>` tag. By default, files
are loaded relatively to the HTML page as `./{bundleName}.js`.

Interally, bundles loading uses Modular's `Require` class, and this class has a few
properties you can change to adjust to your deployment structure.

The real URL of the bundles is then: `Require.jsPath + bundleName + Require.jsExt`

### Specifying base URL

```haxe
Require.jsPath = './'; // default
Require.jsPath = '/scripts/'; // subfolder
Require.jsPath = 'https://path-to-static-domain/'; // other domain
```

### Specifying the extension (and busting cache)

```haxe
Require.jsExt = '.js'; // default
Require.jsPath = '.js?c=' + Math.random(); // cache buster
Require.jsPath = '.js?v=' + VERSION; // versioning
```
