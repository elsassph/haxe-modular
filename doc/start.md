# Getting started with Haxe Modular

For complete architecture examples using this technique you can consult:

- [Haxe React+Redux sample](https://github.com/elsassph/haxe-react-redux)
- [Haxe React+MMVC sample](https://github.com/elsassph/haxe-react-mmvc)


## Overview of solution

1. In the browser, NPM dependencies have to be bundled separately in lib/vendor JS file

	Modular provides a pattern to consume NPM libraries safely.

	- [Set up NPM dependencies](npm-setup.md)

2. Haxe-JS code and sourcemaps splitting, and lazy-loading

	Code splitting works by identifying features which can be asynchronously loaded at
	run time. JS bundles can be created automatically when using Modular's async API.

	- [Haxe library usage](library-usage.md)

4. Hot-reload

	Modular offers code hot-reloading capabilities.

	- [Hot module replacement](hmr-usage.md)


## Known limitations

### Troubleshooting

Modular recognises a few additional debugging flags:

- `-D modular_dump`: generate an additional `.graph` file to analyse the dependency graph,
- `-D modular_debugmap`: generate, for each module, an additional `.map.html` file
  showing a visual representation of the sourcemap.

### Dynamic instantiation

Using reflection (e.g. `Type.resolveClass`) doesn't create link between classes, so such 
types will land in the main bundle. [It can be controlled](advanced.md)

### Magic init

If you don't know what static `__init__` is, don't worry about it!
([if you're curious](http://old.haxe.org/doc/advanced/magic#initialization-magic))

When using `__init__` you may generate code that will be difficult to attribute to the
right context:

- assume that `__init__` code could be duplicated in all the bundles,
- unless you only use calls to static methods.

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
