# Haxe Modular

Code splitting and hot-reload for Haxe JavaScript applications.

## Why?

If you use **Haxe for JavaScript**, directly or indirectly (OpenFl, Kha...), then 
you probably want to:

- make your web app load instantly,
- make your HTML5 game load quicker,
- load sections / features / mini-games on-demand.

Haxe has an excellent, compact and optimised JS output, but it's always a single file; 
even with good minification / gzip compression it can be a large payload.

**Modular can split Haxe-JS output into load-on-demand features, without size/speed overhead,
and without losing sourcemaps.**

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

In both cases, it is advisable to read [how does Haxe compile to JavaScript, and how does on-demand loading work?](doc/how.md).
