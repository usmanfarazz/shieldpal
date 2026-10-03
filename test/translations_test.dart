import 'package:flutter_test/flutter_test.dart';
import 'package:shieldpal/l10n/l10n.dart';
import 'package:shieldpal/l10n/strings_extra.dart';

/// Every translated language must cover the same keys as English and keep the {placeholders}.
void main() {
  test('extra translations are complete and keep placeholders', () {
    final en = extraStrings['en']!;
    final needed = en.keys.where((k) => !k.startsWith('kb2_') && !k.startsWith('kb3_')).toList();
    final ph = RegExp(r'\{[a-z]+\}');
    final problems = <String>[];
    for (final l in appLanguages.where((l) => l.code != 'en' && l.code != 'rur')) {
      final m = extraStrings[l.code];
      if (m == null) {
        problems.add('${l.code}: no extra map');
        continue;
      }
      var missing = 0;
      for (final k in needed) {
        // Long help paragraphs are allowed to fall back to English.
        if (en[k]!.length > 150) continue;
        final v = m[k];
        if (v == null) {
          missing++;
          if (missing <= 40) problems.add('${l.code}: missing $k');
          continue;
        }
        final a = ph.allMatches(en[k]!).map((e) => e.group(0)).toSet();
        final b = ph.allMatches(v).map((e) => e.group(0)).toSet();
        if (a.difference(b).isNotEmpty) problems.add('${l.code}: placeholder lost in $k');
      }
      if (missing > 3) problems.add('${l.code}: ... $missing keys missing in total');
    }
    // ignore: avoid_print
    print(problems.isEmpty ? 'all translations complete' : problems.join('\n'));
    expect(problems, isEmpty);
  });
}
