# How does it work?

## How does Haxe compile to JavaScript?

JavaScript is one of the target platforms of
[Haxe](http://haxe.org/documentation/introduction/language-introduction.html),
a robust, strictly typed, high level, programming language offering a powerful type system
and FP language features. The compiler stays very fast, even with massive codebases.

The compiler transpiles your Haxe code into regular ES5 code - think like Babel or TypeScript.
The generated code is very fast, compact and easy to read.

Haxe-JS doesn't include any "magic" features: it gives access to the HTML5 or nodejs APIs.

```haxe
import js.Browser.document;

class Example {
  static function main() {
    var message = 'Hello world!';
    document.body.innerHTML = '<h1>$message</h1>';
  }
}
```

Unlike other compile-to-JS languages, the Haxe compiler doesn't transpile individual files,
but instead, like Closure compiler or Rollup.js, the compiler outputs one single file.

Haxe Modular can automatically break this output into separate files.

## How does on-demand code loading work?

Let's say you have have these 2 classes:

```haxe
// Example.hx
class Example {
  static function main() {
    load(Foobar).then(function(_) {
      var f = new Foobar();
    }
  }
}

// Foobar.hx
class Foobar {
  public function new() {
    trace('Oh hi!');
  }
}
```

This will emit 2 JS files: `index.js` and `Foobar.js`, which will look a bit like that:
(not real code)

```javascript
// index.js
var Foobar;
function Example() {}
Example.main = function() {
  loadScript("Foobar.js").then(function() {
    Foobar = $hx_scope.Foobar;
    var f = new Foobar();
  })
}
Example.main();

// Foobar.js
function Foobar() {
  console.log("Oh hi!");
}
$hx_scope.Foobar = Foobar;
```

Hopefully what happens is understandable:
- shared classes are attached to a global object, `$hx_scope`,
- when `Foobar.js` gets loaded it defines `$hx_scope.Foobar`,
- in `index.js`, a locally scoped variable `Foobar` is declared,
- after `Foobar.js` is loaded, `Foobar = $hx_scope.Foobar` copies the global 
reference from `$hx_scope` in the local `Foobar` variable,
- then any code using the `Foobar` class will function normally.

Always read Haxe's generated JavaScript code; it is very helpful, and not that
complicated, to understand what is happening.

Haxe Modular keeps the compiler output as-is, just adding the shared scope logic:
it adds very little code and has zero impact on performance.
