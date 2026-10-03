import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 6238 time-based one-time passwords (the same codes Google
/// Authenticator shows) plus otpauth:// QR parsing.
class TotpAccount {
  final String id;
  final String issuer;
  final String label;
  final String secret; // base32
  final int digits;
  final int period;
  final String algorithm; // SHA1, SHA256, SHA512

  TotpAccount({
    required this.id,
    required this.issuer,
    required this.label,
    required this.secret,
    this.digits = 6,
    this.period = 30,
    this.algorithm = 'SHA1',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'issuer': issuer,
        'label': label,
        'secret': secret,
        'digits': digits,
        'period': period,
        'algorithm': algorithm,
      };

  factory TotpAccount.fromJson(Map<String, dynamic> j) => TotpAccount(
        id: j['id'] as String,
        issuer: j['issuer'] as String? ?? '',
        label: j['label'] as String? ?? '',
        secret: j['secret'] as String,
        digits: j['digits'] as int? ?? 6,
        period: j['period'] as int? ?? 30,
        algorithm: j['algorithm'] as String? ?? 'SHA1',
      );

  String codeAt(DateTime time) => Totp.generate(
        secret,
        time,
        digits: digits,
        period: period,
        algorithm: algorithm,
      );

  int secondsLeft(DateTime time) => period - (time.millisecondsSinceEpoch ~/ 1000) % period;

  /// Parses `otpauth://totp/Issuer:user@mail.com?secret=XXXX&issuer=Issuer`.
  static TotpAccount? fromUri(String raw) {
    Uri uri;
    try {
      uri = Uri.parse(raw.trim());
    } catch (_) {
      return null;
    }
    if (uri.scheme != 'otpauth' || uri.host != 'totp') return null;
    final secret = uri.queryParameters['secret'];
    if (secret == null || Totp.base32Decode(secret) == null) return null;
    var path = Uri.decodeComponent(uri.path.replaceFirst('/', ''));
    var issuer = uri.queryParameters['issuer'] ?? '';
    var label = path;
    if (path.contains(':')) {
      final i = path.indexOf(':');
      if (issuer.isEmpty) issuer = path.substring(0, i);
      label = path.substring(i + 1).trim();
    }
    return TotpAccount(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      issuer: issuer,
      label: label,
      secret: secret.replaceAll(' ', '').toUpperCase(),
      digits: int.tryParse(uri.queryParameters['digits'] ?? '') ?? 6,
      period: int.tryParse(uri.queryParameters['period'] ?? '') ?? 30,
      algorithm: (uri.queryParameters['algorithm'] ?? 'SHA1').toUpperCase(),
    );
  }
}

class Totp {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static Uint8List? base32Decode(String input) {
    final s = input.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
    if (s.isEmpty) return null;
    final out = <int>[];
    var buffer = 0, bits = 0;
    for (final ch in s.split('')) {
      final v = _alphabet.indexOf(ch);
      if (v < 0) return null;
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xff);
      }
    }
    return Uint8List.fromList(out);
  }

  static String base32Encode(List<int> bytes) {
    final sb = StringBuffer();
    var buffer = 0, bits = 0;
    for (final b in bytes) {
      buffer = (buffer << 8) | b;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        sb.write(_alphabet[(buffer >> bits) & 31]);
      }
    }
    if (bits > 0) sb.write(_alphabet[(buffer << (5 - bits)) & 31]);
    return sb.toString();
  }

  static String randomSecret([int bytes = 20]) {
    final r = Random.secure();
    return base32Encode(List<int>.generate(bytes, (_) => r.nextInt(256)));
  }

  static int hotp(List<int> key, int counter, {String algorithm = 'SHA1'}) {
    // Two 32-bit writes instead of setUint64 so this also works on the web.
    final msg = ByteData(8)
      ..setUint32(0, counter ~/ 0x100000000)
      ..setUint32(4, counter % 0x100000000);
    final Hash h = switch (algorithm) {
      'SHA256' => sha256,
      'SHA512' => sha512,
      _ => sha1,
    };
    final mac = Hmac(h, key).convert(msg.buffer.asUint8List()).bytes;
    final offset = mac.last & 0x0f;
    return ((mac[offset] & 0x7f) << 24) |
        ((mac[offset + 1] & 0xff) << 16) |
        ((mac[offset + 2] & 0xff) << 8) |
        (mac[offset + 3] & 0xff);
  }

  static String generate(String secret, DateTime time,
      {int digits = 6, int period = 30, String algorithm = 'SHA1'}) {
    final key = base32Decode(secret);
    if (key == null) return '------';
    final counter = (time.millisecondsSinceEpoch ~/ 1000) ~/ period;
    final code = hotp(key, counter, algorithm: algorithm) % pow(10, digits).toInt();
    return code.toString().padLeft(digits, '0');
  }

  static String hashPin(String pin) =>
      sha256.convert(utf8.encode('shieldpal:$pin')).toString();
}
