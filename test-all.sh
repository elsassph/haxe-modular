#!/bin/sh

npx lix use haxe 3.4.7
npm run test > logs-3.4.7.txt

npx lix use haxe 4.0.5
npm run test > logs-4.0.5.txt
npm run test es6 > logs-4.0.5-es6.txt

npx lix use haxe 4.1.5
npm run test > logs-4.1.5.txt
npm run test es6 > logs-4.1.5-es6.txt

npx lix use haxe stable
npm run test > logs-stable.txt
npm run test es6 > logs-stable-es6.txt
