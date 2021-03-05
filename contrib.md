# Contribution

## Installation

```bash
npm install
```

The `postinstall` step will install the Haxe SDK and needed libraries using `lix`.

Sources:

- `/src`: Haxe Modular library client support
- `/tool`: Modular CLI

## Building and testing

```bash
# build CLI and viewer
npm run build:cli
npm run build:viewer

# run tests (optional ES6 output flag)
npm run test
npm run test -- es6

# run single suite
npm run test -- web-debug
npm run test -- es6 web-debug

# run single test
npm run test -- web-debug Test1
npm run test -- es6 web-debug Test1

# run interop tests only
npm run test -- interop
npm run test -- es6 interop

# run test and force-update the "expect" control files
UPDATE_EXPECT=true npm run test
```
