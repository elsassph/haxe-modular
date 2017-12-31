# Haxe Modular

Code splitting and hot-reload for Haxe JavaScript applications.

## Why?

**The fastest, most compressed, code is the code you don't download.**

Haxe has an excellent, compact and optimised JS output, but it's always a single file:
Modular can split this JS file into load-on-demand features, without size/speed overhead,
and without losing sourcemaps.

## How?

```haxe
import MyClass;
...
load(MyClass).then(function(_) {
	var c = new MyClass();
});
```

The approach is to *reference one class asynchronously* in your code:

- **at compile time**, the *dependency graph* of the class is built and one additional JS
file will be emitted (bundling this class and all its dependencies),
- **at run time**, when the aynchronous reference is evaluated, the additional JS is
loaded (once) automatically.

Note: Haxe Modular is NOT a solution for extracting libraries, single files or
entire packages; it is "usage" based.

## Where to start?

There are 2 ways to use Haxe Modular, depending on your project/toolchain/goals:

- [standalone Modular](doc/start.md); zero dependencies, drop-in any Haxe-JS project,
- [Webpack Haxe Loader](https://github.com/jasononeil/webpack-haxe-loader); leverage the famous JS toolchain.

## How does Haxe-JS work?

```haxe
import js.Browser.document;

class Example {
	static function main() {
		var message = 'Hello world!';
		document.body.innerHTML = '<h1>$message</h1>';
	}
}
```

JavaScript is one of the target platforms of
[Haxe](http://haxe.org/documentation/introduction/language-introduction.html),
a robust, strictly typed, high level, programming language offering a powerful type system
and FP language features. The compiler stays very fast, even with massive codebases.

Haxe-JS doesn't include any "magic" features: it gives access to the HTML5 or nodejs APIs.

Haxe transpiles your Haxe code into regular ES5 code, with polyfills for the 
language-specific features.

Unlike other compile-to-JS languages, the Haxe compiler doesn't transpile individual files,
but instead, like Closure compiler or Rollup.js, the compiler outputs one single file.
Haxe Modular can automatically break this output into separate files.
