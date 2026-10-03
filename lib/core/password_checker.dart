import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class PasswordReport {
  final int strength; // 0..4
  final double bits;
  final String crackTime; // human readable, English units handled by UI
  final double crackSeconds;
  final List<String> tips; // localisation keys
  final int? breachCount; // null = not checked
  PasswordReport(this.strength, this.bits, this.crackTime, this.crackSeconds, this.tips, this.breachCount);
}

class PasswordChecker {
  static const _common = {
    '123456', '123456789', '12345678', 'password', 'qwerty', '111111', '123123',
    'abc123', '1234567', 'password1', '12345', '000000', 'iloveyou', '1234',
    'pakistan', 'pakistan123', 'india123', 'freefire', 'free fire', 'qwerty123',
    'admin', 'welcome', 'monkey', 'dragon', 'football', 'cricket', 'baseball',
    'letmein', 'sunshine', 'princess', 'zaq12wsx', '786786', '786', 'allah786',
    'bismillah', 'asdfgh', 'asdf1234', 'qwertyuiop', '654321', '7777777', 'pass123',
  };

  static PasswordReport analyze(String pw, {int? breachCount}) {
    final tips = <String>[];
    var pool = 0;
    if (RegExp(r'[a-z]').hasMatch(pw)) pool += 26;
    if (RegExp(r'[A-Z]').hasMatch(pw)) pool += 26;
    if (RegExp(r'\d').hasMatch(pw)) pool += 10;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(pw)) pool += 33;
    var bits = pw.isEmpty ? 0.0 : pw.length * (log(max(pool, 1)) / ln2);

    final lower = pw.toLowerCase();
    if (_common.contains(lower) || _common.contains(lower.replaceAll(RegExp(r'\d+$'), ''))) {
      bits = min(bits, 10);
      tips.add('p_common');
    }
    if (RegExp(r'(.)\1{2,}').hasMatch(pw)) {
      bits *= 0.8;
      tips.add('p_repeat');
    }
    if (RegExp(r'(0123|1234|2345|3456|4567|5678|6789|abcd|qwer|asdf|zxcv)', caseSensitive: false).hasMatch(pw)) {
      bits *= 0.75;
      tips.add('p_sequence');
    }
    if (RegExp(r'(19|20)\d{2}').hasMatch(pw)) {
      bits *= 0.9;
      tips.add('p_year');
    }
    if (pw.length < 12) tips.add('p_length');
    if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(pw)) tips.add('p_symbol');
    if (!RegExp(r'[A-Z]').hasMatch(pw) || !RegExp(r'[a-z]').hasMatch(pw)) tips.add('p_case');

    // Fast offline attacker: 10 billion guesses / second.
    final seconds = pow(2, bits) / 2 / 1e10;
    final strength = bits < 28
        ? 0
        : bits < 40
            ? 1
            : bits < 60
                ? 2
                : bits < 80
                    ? 3
                    : 4;
    if (breachCount != null && breachCount > 0) tips.insert(0, 'p_breached');
    return PasswordReport(
      breachCount != null && breachCount > 0 ? 0 : strength,
      bits,
      _human(seconds.toDouble()),
      seconds.toDouble(),
      tips,
      breachCount,
    );
  }

  static String _human(double s) {
    if (s < 1) return '<1 s';
    if (s < 60) return '${s.round()} s';
    if (s < 3600) return '${(s / 60).round()} min';
    if (s < 86400) return '${(s / 3600).round()} h';
    if (s < 31536000) return '${(s / 86400).round()} d';
    final y = s / 31536000;
    if (y < 1000) return '${y.round()} y';
    if (y < 1e6) return '${(y / 1000).round()}K y';
    if (y < 1e9) return '${(y / 1e6).round()}M y';
    return '∞';
  }

  /// Have I Been Pwned "range" API. Only the first 5 characters of the
  /// SHA-1 hash leave the phone, so the password itself is never sent.
  static Future<int?> breachCount(String pw) async {
    if (pw.isEmpty) return null;
    final hash = sha1.convert(utf8.encode(pw)).toString().toUpperCase();
    final prefix = hash.substring(0, 5);
    final suffix = hash.substring(5);
    try {
      final res = await http
          .get(Uri.parse('https://api.pwnedpasswords.com/range/$prefix'), headers: {'Add-Padding': 'true'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      for (final line in const LineSplitter().convert(res.body)) {
        final parts = line.split(':');
        if (parts.length == 2 && parts[0] == suffix) return int.tryParse(parts[1].trim()) ?? 0;
      }
      return 0;
    } catch (_) {
      return null;
    }
  }

  static String generate({int length = 16}) {
    const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#\$%&*?-_+=';
    final r = Random.secure();
    String pw;
    do {
      pw = List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
    } while (!(RegExp(r'[a-z]').hasMatch(pw) &&
        RegExp(r'[A-Z]').hasMatch(pw) &&
        RegExp(r'\d').hasMatch(pw) &&
        RegExp(r'[^a-zA-Z0-9]').hasMatch(pw)));
    return pw;
  }
}
