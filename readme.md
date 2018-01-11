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

*Modular can split gigantic Haxe-JS outputs into load-on-demand features, 
without size/speed overhead, and without losing sourcemaps.*

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
entire packages; it is "usage" based and can slice the biggest libraries to keep only .

## Where to start?

There are 2 ways to use Haxe Modular, depending on your project/toolchain/goals:

1. [standalone Modular](doc/start.md); zero dependencies, for any Haxe-JS project,
2. [Webpack Haxe Loader](https://github.com/jasononeil/webpack-haxe-loader); 
   leverage the famous JS toolchain.

In both cases, it is advisable to read about the technical details: 

- [How does Haxe compile to JavaScript, and how does on-demand loading work?](doc/how.md)
- [How to add advanced control of the splitting logic?](doc/advanced.md)

### What is the difference?

Both solutions:

- use Modular splitting under the hood,
- split automatically using a single `hxml` build configuration,
- support NPM dependencies,
- allow hot-reloading of code.

### What should I use?

1. [Standalone Modular](doc/start.md) is an easy, drop-in, addition to a regular 
   Haxe JS build process - it is very lightweight and unobstrusive, and you don't need 
   to learn Webpack.

   Using NPM modules however requires a bit of ceremony: all the NPM dependencies have to 
   be gathered (manually) in a `libs.js` which is loaded upfront.

2. [Webpack Haxe Loader](https://github.com/jasononeil/webpack-haxe-loader) is a more 
   powerful setup but you'll have to learn Webpack. Webpack is a complex and large system 
   offering vast possibilities from the JS ecosystem.
