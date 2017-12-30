# Hot Module Replacement

## LiveReload server

The feature is based on the [LiveReload](https://livereload.com) API. Haxe API will
set a listener for `LiveReloadConnect` and register a "reloader plugin" to handle changes.

All you have to do is to rebuild the Haxe-JS application and let LiveReload inform our
running application to reload some of the JavaScript files.

Stylesheets and static images will be normally live reloaded.

#### Livereloadx

[livereloadx](http://nitoyon.github.io/livereloadx/) is a nice nodejs implementation of
the LiveReload server.

	npm install livereloadx -g

#### Static mode

It is recommended to simply use the static mode to serve your web app and dynamically
inject the livereload client API script in the HTML page:

	livereloadx -s bin/
	open http://localhost:35729

#### Custom server mode

If you need an advanced server, with URL rewriting for instance, you can run the
server separately and load the LiveReload client script yourself:

	livereloadx bin/

```html
<script>document.write('<script src="http://' + (location.host||'localhost').split(':')[0] +
':35729/livereload.js?snipver=2"></' + 'script>')</script>
```


## Haxe API

Calling `Require.hot` will set up a LiveReload hook. When a JS file loaded using
`Require.module` change, it will be automatically reloaded and the callbacks will
be triggered to allow the application to handle the change.

```haxe
#if debug
Require.hot(function(_) {
	// Some lazy-loaded module has been reloaded (eg. 'view.js').
	// Class myapp.view.MyAppView reference has now been updated,
	// and new instances will use the newly loaded code!
	// It's time to re-render / replace the view.
	new MyAppView();
});
#end
```

**Important:**

- hot-reload does NOT update code in existing instances - you must create new
instances (or patch live instances) of reloaded classes to use the new code,
- hot-reload does NOT reload the index JS file; you must reload the page manually.

### API

`Require.hot(?handler:String -> Void, ?forModule:String):Void`

- `handler`: a callback to be notified of modules having reloaded
- `forModule`: if provided, only be notified of a specific module changes

## React HMR wrapper

When using hot-reload for React views you will want to use the handy `autoRefresh` wrapper.

This feature leverages [react-proxy](https://github.com/gaearon/react-proxy/tree/master) and
and [react-deep-force-update](https://github.com/gaearon/react-deep-force-update) just like
the "official" React HMR does under the hood.

1. In your NPM `libs.js`, make sure to include the following snippets:

    ```javascript
    if (process.env.NODE_ENV !== 'production') {
        // enable React HMR proxy
        require('haxe-modular');
    }
    ```

1. Add `-D react_hot` in your Haxe compiler options to generate the HMR hook logic.

3. And in your Haxe code, where your main `ReactDOM.render` happens:

    ```haxe
    var rootNode = ReactDOM.render(...);

    #if (debug && react_hot)
    ReactHMR.autoRefresh(rootNode);
    #end
    ```

That's all, but note:
- HMR only works in `-debug` mode,
- only components in split bundles will reload.
