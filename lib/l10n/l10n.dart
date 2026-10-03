import 'package:flutter/widgets.dart';

import 'strings_ar.dart';
import 'strings_bn.dart';
import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_extra.dart';
import 'strings_es.dart';
import 'strings_fr.dart';
import 'strings_hi.dart';
import 'strings_id.dart';
import 'strings_pt.dart';
import 'strings_ru.dart';
import 'strings_rur.dart';
import 'strings_tr.dart';
import 'strings_ur.dart';
import 'strings_zh.dart';

class AppLanguage {
  final String code; // our own code ("rur" = Roman Urdu)
  final String nativeName;
  final Locale materialLocale; // locale used for Flutter's built-in widgets
  final String ttsLocale; // voice for spoken alerts
  final Map<String, String> strings;
  const AppLanguage(this.code, this.nativeName, this.materialLocale, this.ttsLocale, this.strings);

  bool get rtl => code == 'ar' || code == 'ur';
}

const List<AppLanguage> appLanguages = [
  AppLanguage('en', 'English', Locale('en'), 'en-US', stringsEn),
  AppLanguage('ur', 'اردو', Locale('ur'), 'ur-PK', stringsUr),
  AppLanguage('rur', 'Roman Urdu', Locale('en'), 'ur-PK', stringsRur),
  AppLanguage('hi', 'हिन्दी', Locale('hi'), 'hi-IN', stringsHi),
  AppLanguage('ar', 'العربية', Locale('ar'), 'ar-SA', stringsAr),
  AppLanguage('bn', 'বাংলা', Locale('bn'), 'bn-BD', stringsBn),
  AppLanguage('es', 'Español', Locale('es'), 'es-ES', stringsEs),
  AppLanguage('fr', 'Français', Locale('fr'), 'fr-FR', stringsFr),
  AppLanguage('pt', 'Português', Locale('pt'), 'pt-BR', stringsPt),
  AppLanguage('id', 'Bahasa Indonesia', Locale('id'), 'id-ID', stringsId),
  AppLanguage('tr', 'Türkçe', Locale('tr'), 'tr-TR', stringsTr),
  AppLanguage('ru', 'Русский', Locale('ru'), 'ru-RU', stringsRu),
  AppLanguage('de', 'Deutsch', Locale('de'), 'de-DE', stringsDe),
  AppLanguage('zh', '中文', Locale('zh'), 'zh-CN', stringsZh),
];

AppLanguage languageFor(String code) =>
    appLanguages.firstWhere((l) => l.code == code, orElse: () => appLanguages.first);

/// Picks the best language for the phone's system locale on first launch.
String detectLanguage(Locale system) {
  final c = system.languageCode;
  if (appLanguages.any((l) => l.code == c)) return c;
  return 'en';
}

class L10n {
  static AppLanguage current = appLanguages.first;

  /// Translate [key]; falls back to English, then to the key itself.
  /// `{name}` placeholders are filled from [args].
  static String t(String key, [Map<String, Object?> args = const {}]) {
    var s = current.strings[key] ?? extraStrings[current.code]?[key] ?? extraStrings['en']?[key] ?? stringsEn[key] ?? key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }
}

String tr(String key, [Map<String, Object?> args = const {}]) => L10n.t(key, args);

/// Translate [key] into a specific language [code] (Pal AI answers in the
/// language the user typed, which can differ from the app language).
String trIn(String code, String key, [Map<String, Object?> args = const {}]) {
  final lang = languageFor(code);
  var s = lang.strings[key] ?? extraStrings[code]?[key] ?? extraStrings['en']?[key] ?? stringsEn[key] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}
