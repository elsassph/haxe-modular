# Extracting libraries

## Foreword

Splitting entire libraries is a common requested features, and it is now possible.

*It isn't a silver bullet, and inherent limitations generally prevents splitting 
libraries like OpenFl/Lime which are typically extended by your application entry point.*

The reality is that you should be first looking into splitting your application 
code, before considering splitting libraries.

Splitting your application code means identifying entire features that can be loaded
on demand - this is where normally the biggest win for complex applications.

## API

```haxe
import com.myLib.Something;
...
Bundle.loadLib('mylib', ['com.myLib', 'foo.otherlib']).then(function(_) {
    var s = new Something();
});
```

Libraries follow a similar API to the normal `Bundle.load` method, but instead 
you get to specify a library name, and a list of **packages** you want to split.

A JavaScript file named `mylib.js` would be emitted here, including all the classes 
from the specified packages, and their dependencies.

## Limitations (important)

### Only packages, not classes

Individual classes can NOT be selected to go in a library.

*This limitation will be lifted in the future*

### Libraries must be loaded by the main bundle.

At the moment, only the application entry point can load libraries.

*This limitation will be lifted in the future*

### Class extend/implement limitation

Libraries works as expected for child bundles, where you can freely reference classes
from libraries, however there are limitations for the main bundle.

Classes from the main bundle:

- can NOT extend classes from libraries,
- can NOT implement interfaces from libraries.

*This can NOT be resolved in the future*

Aside from that, you can use `cast`, `Std.is`, `Type.resolveClass`, etc. for 
any class from the libraies, provided the library is loaded.
