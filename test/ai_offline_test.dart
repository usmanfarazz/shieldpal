import 'package:flutter_test/flutter_test.dart';
import 'package:shieldpal/core/assistant.dart';
import 'package:shieldpal/l10n/l10n.dart';

void main() {
  test('offline Pal AI answers common questions', () {
    L10n.current = languageFor('rur');
    final qs = [
      'hi', 'kya haal hai', 'hello', 'salam', '2+2', '12 x 5', 'what time is it', 'aaj kya tareekh hai',
      'shieldpal kya hai', 'is it free', 'kisne banaya', 'mera data safe hai', 'vpn pornhub site nahi khul rahi',
      'app khud band ho jati hai', 'sim kis ke naam hai', 'i love you', 'mujhe bore ho raha hai', 'mera account hack ho gaya',
      'kisi ne otp manga', 'free fire diamonds link', 'thanks', 'allah hafiz', 'good morning', 'tell me a joke',
      'how are you', 'what is meta', 'who is the prime minister',
    ];
    var fallback = 0;
    for (final q in qs) {
      final r = Assistant.offlineReply(q, 'bella');
      final fb = r.startsWith('Is ke baare mein abhi') || r.startsWith("I'm not sure");
      if (fb) fallback++;
      // ignore: avoid_print
      print('${fb ? "FALLBACK" : "ok      "} [${Assistant.isSmallTalk(q) ? "instant" : "online "}] $q -> ${r.replaceAll('\n', ' ').substring(0, r.length < 70 ? r.length : 70)}');
    }
    // ignore: avoid_print
    print('fallbacks: $fallback / ${qs.length}');
    expect(fallback, lessThanOrEqualTo(3));
  });
}
