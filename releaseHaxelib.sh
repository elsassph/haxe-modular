#!/bin/sh
rm -f haxe-modular.zip
zip -r haxe-modular.zip src doc extraParams.hxml haxelib.json readme.md
haxelib submit haxe-modular.zip $1 --always
