import 'package:flutter_test/flutter_test.dart';
import 'package:shieldpal/core/assistant.dart';

void main() {
  test('Pal AI detects the language the user typed', () {
    final cases = <(String, String, String)>[
      ('my free fire account got hacked', 'rur', 'en'),
      ('someone asked me for my OTP', 'rur', 'en'),
      ('what is phishing?', 'rur', 'en'),
      ('mera free fire account hack ho gaya', 'en', 'rur'),
      ('kya haal hai', 'en', 'rur'),
      ('hi', 'rur', 'rur'),
      ('hi', 'en', 'en'),
      ('میرا اکاؤنٹ ہیک ہو گیا ہے', 'en', 'ur'),
      ('मेरा अकाउंट हैक हो गया', 'en', 'hi'),
      ('мой аккаунт взломали', 'en', 'ru'),
      ('hesabım hacklendi merhaba', 'en', 'tr'),
      ('hola, me hackearon la cuenta', 'en', 'es'),
      ('bonjour, comment ça va', 'en', 'fr'),
      ('hallo, wie geht es dir', 'en', 'de'),
      ('我的账号被盗了', 'en', 'zh'),
      ('مرحبا حسابي تعرض للاختراق', 'en', 'ar'),
    ];
    for (final c in cases) {
      expect(LangDetect.detect(c.$1, c.$2), c.$3, reason: '"${c.$1}" (app ${c.$2})');
    }
  });
}
