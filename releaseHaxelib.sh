#!/bin/sh

rm -f haxe-modular.zip
zip -r haxe-modular.zip src extraParams.hxml haxelib.json readme.md
haxelib submit haxe-modular.zip
