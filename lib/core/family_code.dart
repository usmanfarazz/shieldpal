import 'dart:convert';

import 'totp.dart';

/// Family Safe-Word: every member of a circle shares a secret (exchanged by
/// scanning a QR code in person). From it each phone shows the same three
/// emojis that change every few minutes. On a suspicious call ("Mom, I'm in
/// trouble, send money!") ask for the emojis - a scammer with a cloned voice
/// cannot know them. Emojis work in every language.
class FamilyCircle {
  final String id;
  final String name;
  final String secret;
  final int period; // seconds

  FamilyCircle({required this.id, required this.name, required this.secret, this.period = 300});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'secret': secret, 'period': period};
  factory FamilyCircle.fromJson(Map<String, dynamic> j) => FamilyCircle(
        id: j['id'] as String,
        name: j['name'] as String,
        secret: j['secret'] as String,
        period: j['period'] as int? ?? 300,
      );

  static const List<String> emojis = [
    '🍎', '🍌', '🍇', '🍉', '🍓', '🍒', '🥭', '🍍', '🥥', '🥕', '🌽', '🌶️', '🍄', '🥜', '🍞', '🧀',
    '🍕', '🍔', '🍟', '🌮', '🍩', '🍪', '🎂', '🍫', '🍿', '🥤', '☕', '🍵', '🐶', '🐱', '🐭', '🐰',
    '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🦆', '🦉', '🐴',
    '🦄', '🐝', '🦋', '🐢', '🐍', '🐙', '🐬', '🐳', '🦈', '🐊', '🦒', '🐘', '🦘', '🐪', '🌵', '🌲',
    '🌴', '🌻', '🌹', '🌷', '🍀', '🍁', '🌙', '⭐', '☀️', '⛅', '🌈', '❄️', '🔥', '💧', '🌊', '⚡',
    '🌍', '🏔️', '🏝️', '🏠', '🏰', '⛺', '🚗', '🚕', '🚌', '🚑', '🚒', '🚲', '🛵', '🚂', '✈️', '🚀',
    '🛸', '⛵', '⚓', '🎈', '🎁', '🎀', '🎉', '🎨', '🎸', '🎹', '🥁', '🎺', '🎻', '🎮', '🎲', '🧩',
    '⚽', '🏀', '🏏', '🏸', '🎾', '🏓', '🥊', '🏆', '🥇', '👑', '💎', '🔑', '🔒', '💡', '📚', '✏️',
    '📷', '📱', '💻', '⌚', '🔭', '🧲', '🧸', '🪁', '🕹️', '🛼', '🧭', '⏰', '🎩', '👓', '🧢', '👟',
  ];

  List<String> codeAt(DateTime time) {
    final key = Totp.base32Decode(secret) ?? utf8.encode(secret);
    final counter = (time.millisecondsSinceEpoch ~/ 1000) ~/ period;
    final v = Totp.hotp(key, counter, algorithm: 'SHA256');
    final n = emojis.length;
    return [emojis[v % n], emojis[(v ~/ n) % n], emojis[(v ~/ (n * n)) % n]];
  }

  int secondsLeft(DateTime time) => period - (time.millisecondsSinceEpoch ~/ 1000) % period;

  /// Text encoded in the pairing QR code.
  String toQr() => 'shieldpal://family?v=1&name=${Uri.encodeComponent(name)}&s=$secret&p=$period';

  static FamilyCircle? fromQr(String raw) {
    try {
      final u = Uri.parse(raw.trim());
      if (u.scheme != 'shieldpal' || u.host != 'family') return null;
      final s = u.queryParameters['s'];
      if (s == null || Totp.base32Decode(s) == null) return null;
      return FamilyCircle(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: u.queryParameters['name'] ?? 'Family',
        secret: s,
        period: int.tryParse(u.queryParameters['p'] ?? '') ?? 300,
      );
    } catch (_) {
      return null;
    }
  }
}
