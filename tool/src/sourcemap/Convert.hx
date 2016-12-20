package sourcemap;
import js.RegExp;

@:jsRequire('convert-source-map')
extern class Convert
{
	static public function fromObject(obj:Dynamic):Convert;
	static public function fromJson(json:String):Convert;
	static public function fromBase64(base64:String):Convert;
	static public function fromComment(comment:String):Convert;
	static public function fromMapFileComment(comment:String, mapFileDir:String):Convert;
	static public function fromMapFileSource(comment:String, mapFileDir:String):Convert;
	
	public function toOBject():Dynamic;
	public function toJson(?space:String):String;
	public function toComment(?options:Dynamic):String;
	public function addProperty(key:String, value:Dynamic):Convert;
	public function setProperty(key:String, value:Dynamic):Convert;
	public function getProperty(key:String):Dynamic;
	public function removeComments(src:String):String;
	public function removeMapFileComments(src:String):String;
	public function commentRegex():RegExp;
	public function generateMapFileComment(file:String, ?options:Dynamic):Void;
	
}