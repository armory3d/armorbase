package arm;

import arm.Enums;

@:keep
class Console {

	public static var message = "";
	public static var messageTimer = 0.0;
	public static var messageColor = 0x00000000;
	public static var lastTraces: Array<String> = [""];
	static var haxeTrace: Dynamic->haxe.PosInfos->Void = null;

	public static function info(s: String) {
		messageTimer = 5.0;
		message = s;
		messageColor = 0x00000000;
		App.redrawStatus();
		consoleTrace(s);
	}

	public static function error(s: String) {
		messageTimer = 8.0;
		message = s;
		messageColor = 0xffaa0000;
		App.redrawStatus();
		consoleTrace(s);
	}

	public static function log(s: String) {
		consoleTrace(s);
	}

	public static function init() {
		if (haxeTrace == null) {
			haxeTrace = haxe.Log.trace;
			haxe.Log.trace = consoleTrace;
		}
	}

	static function consoleTrace(v: Dynamic, ?inf: haxe.PosInfos) {
		App.redrawConsole();
		lastTraces.unshift(Std.string(v));
		if (lastTraces.length > 100) lastTraces.pop();
		haxeTrace(v, inf);
	}
}
