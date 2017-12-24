# Getting started with Haxe Modular

For complete architecture examples using this technique you can consult:

- [Haxe React+Redux sample](https://github.com/elsassph/haxe-react-redux)
- [Haxe React+MMVC sample](https://github.com/elsassph/haxe-react-mmvc)


## Overview of solution

1. In the browser, NPM dependencies have to be bundled separately in lib/vendor JS file

	Modular provides a pattern to consume NPM libraries; you should not run

	- [Set up NPM dependencies](npm-setup.md)

2. Haxe-JS code and source-maps splitting, and lazy-loading

	Code splitting works by identifying features which can be asynchronously loaded at
	run time. JS bundles can be created automatically by using the `Bundle.load` helper.

	- [Haxe library](library-usage.md)

4. Hot-reload

	A helper class can be used listen to a LiveReload server and reload lazy-loaded
	modules automatically.

	- [Hot module replacement](hmr-usage.md)


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
