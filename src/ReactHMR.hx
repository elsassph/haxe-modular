package;

import js.Browser;
import react.ReactComponent.ReactElement;

class ReactHMR
{
	/**
	 * Deep refresh the provided react root element when a module is reloaded.
	 */
	static public function autoRefresh(rootElement:ReactElement) 
	{
		Require.hot(function(_) {
			var hmr = untyped __REACT_HOT_LOADER__;
			if (hmr != null && hmr.refresh != null) hmr.refresh(rootElement);
			else Browser.location.reload();
		});
	}
}
