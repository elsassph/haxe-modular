#!/bin/bash
set -e

# build split and viewer
haxe build-viewer.hxml
haxe build-tool.hxml

# run tests (optional ES6 output flag)
node tool/test/test-suite.js
# node tool/test/test-suite.js es6

# run single suite
# node tool/test/test-suite.js web-debug
# node tool/test/test-suite.js es6 web-debug

# run single test
# node tool/test/test-suite.js web-debug Test1
# node tool/test/test-suite.js es6 web-debug Test1
