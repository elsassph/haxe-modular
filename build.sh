#!/bin/bash
set -e

# build split and viewer
haxe build-viewer.hxml
haxe build-tool.hxml

# run tests
node tool/test/test-suite.js

# run single suite
# node tool/test/test-suite.js web-debug

# run single test
# node tool/test/test-suite.js web-debug Test1
