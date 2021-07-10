package arm;

import haxe.io.Bytes;
import haxe.Json;
import arm.sys.File;
import arm.sys.Path;

class Translator {

	static var translations: Map<String, String> = [];
	// The font index is a value specific to font_cjk.ttc.
	static var cjkFontIndices: Map<String, Int> = [
		"ja" => 0,
		"ko" => 1,
		"zh_cn" => 2,
		"zh_tw" => 3,
		"zh_tw.big5" => 4
	];

	static var lastLocale = "en";

	// Localizes a string with the given placeholders replaced (format is `{placeholderName}`).
	// If the string isn't available in the translation, this method will return the source English string.
	public static function tr(id: String, vars: Map<String, String> = null): String {
		var translation = id;

		// English is the source language
		if (Config.raw.locale != "en" && translations.exists(id)) {
			translation = translations[id];
		}

		if (vars != null) {
			for (key => value in vars) {
				translation = translation.replace('{$key}', Std.string(value));
			}
		}

		return translation;
	}

	// (Re)loads translations for the specified locale
	public static function loadTranslations(newLocale: String) {
		if (newLocale == "system") {
			Config.raw.locale = Krom.language();
		}

		// Check whether the requested or detected locale is available
		if (Config.raw.locale != "en" && getSupportedLocales().indexOf(Config.raw.locale) == -1) {
			// Fall back to English
			Config.raw.locale = "en";
		}

		// No translations to load, as source strings are in English
		// Clear existing translations if switching languages at runtime
		translations.clear();

		if (Config.raw.locale == "en" && lastLocale == "en") {
			// No need to generate extended font atlas for English locale
			return;
		}
		lastLocale = Config.raw.locale;

		if (Config.raw.locale != "en") {
			// Load the translation file
			var translationJson = Bytes.ofData(Krom.loadBlob('data/locale/${Config.raw.locale}.json')).toString();
			var data: haxe.DynamicAccess<String> = Json.parse(translationJson);
			for (key => value in data) {
				translations[Std.string(key)] = value;
			}
		}

		// Generate extended font atlas
		extendedGlyphs();

		// Push additional char codes contained in translation file
		var cjk = false;
		for (s in translations) {
			for (i in 0...s.length) {
				// Assume cjk in the > 1119 range for now
				if (s.charCodeAt(i) > 1119 && kha.graphics2.Graphics.fontGlyphs.indexOf(s.charCodeAt(i)) == -1) {
					if (!cjk) {
						kha.graphics2.Graphics.fontGlyphs = [for (i in 32...127) i];
						cjk = true;
					}
					kha.graphics2.Graphics.fontGlyphs.push(s.charCodeAt(i));
				}
			}
		}

		var newFont = { path : "font.ttf", scale : 1.0 };
		if (cjk) {
			newFont = { path : "font_cjk.ttc", scale : 1.4 };
			var cjkFontPath = Path.data() + Path.sep + newFont.path;
			if (!File.exists(cjkFontPath)) {
				File.download("https://github.com/armory3d/armorbase/raw/main/Assets/common/extra/font_cjk.ttc", cjkFontPath);
			}
			if (!File.exists(cjkFontPath)) {
				// Fall back to English
				Config.raw.locale = "en";
				extendedGlyphs();
				translations.clear();
				newFont = { path : "font.ttf", scale : 1.0 };
			}
		}

		kha.graphics2.Graphics.fontGlyphs.sort(Reflect.compare);
		// Load and assign font with cjk characters
		iron.App.notifyOnInit(function() {
			iron.data.Data.getFont(newFont.path, function(f: kha.Font) {
				if (cjk) {
					var fontIndex = cjkFontIndices.exists(Config.raw.locale) ? cjkFontIndices[Config.raw.locale] : 0;
					f.setFontIndex(fontIndex);
				}
				App.font = f;
				// Scale up the font size and elements width a bit
				App.theme.FONT_SIZE = Std.int(App.defaultFontSize * newFont.scale);
				App.theme.ELEMENT_W = Std.int(App.defaultElementW * (Config.raw.locale != "en" ? 1.4 : 1.0));
				var uis = App.getUIs();
				for (ui in uis) {
					ui.ops.font = f;
					ui.setScale(ui.ops.scaleFactor);
				}
			});
		});
	}

	static function extendedGlyphs() {
		// Basic Latin + Latin-1 Supplement + Latin Extended-A
		kha.graphics2.Graphics.fontGlyphs = [for (i in 32...383) i];
		// + Greek
		for (i in 880...1023) kha.graphics2.Graphics.fontGlyphs.push(i);
		// + Cyrillic
		for (i in 1024...1119) kha.graphics2.Graphics.fontGlyphs.push(i);
	}

	// Returns a list of supported locales (plus English and the automatically detected system locale)
	public static function getSupportedLocales(): Array<String> {
		var locales = ["system", "en"];
		for (localeFilename in File.readDirectory(Path.data() + Path.sep + "locale")) {
			// Trim the `.json` file extension from file names
			locales.push(localeFilename.substr(0, -5));
		}
		return locales;
	}
}
