import 'family_code.dart';
import 'scam_engine.dart';
import 'totp.dart';
import 'url_analyzer.dart';

/// "Quishing" protection: a QR code can hide a phishing link, a payment to a
/// stranger or a hostile Wi-Fi network. ShieldPal decodes it first and shows
/// what it really is before anything happens.
enum QrKind { url, wifi, payment, otpauth, family, phone, sms, email, geo, crypto, contact, text }

class QrReport {
  final String raw;
  final QrKind kind;
  final int risk;
  final List<String> notes; // localisation keys
  final Map<String, String> details;
  final UrlReport? url;
  final TotpAccount? totp;
  final FamilyCircle? family;

  QrReport({
    required this.raw,
    required this.kind,
    required this.risk,
    this.notes = const [],
    this.details = const {},
    this.url,
    this.totp,
    this.family,
  });
}

class QrAnalyzer {
  static QrReport analyze(String raw) {
    final s = raw.trim();
    final lower = s.toLowerCase();

    if (lower.startsWith('shieldpal://family')) {
      final f = FamilyCircle.fromQr(s);
      return QrReport(raw: s, kind: QrKind.family, risk: f == null ? 40 : 0, family: f,
          notes: [f == null ? 'q_family_bad' : 'q_family']);
    }
    if (lower.startsWith('otpauth://')) {
      final t = TotpAccount.fromUri(s);
      return QrReport(raw: s, kind: QrKind.otpauth, risk: t == null ? 30 : 0, totp: t,
          notes: [t == null ? 'q_otp_bad' : 'q_otp'],
          details: t == null ? {} : {'issuer': t.issuer, 'account': t.label});
    }
    if (lower.startsWith('wifi:')) {
      final fields = <String, String>{};
      for (final m in RegExp(r'([TSPH]):((?:\\.|[^;])*);').allMatches(s.substring(5))) {
        fields[m.group(1)!] = m.group(2)!.replaceAll(r'\;', ';');
      }
      final t = (fields['T'] ?? 'nopass').toUpperCase();
      final notes = <String>[];
      var risk = 0;
      if (t == 'NOPASS' || t.isEmpty) {
        notes.add('q_wifi_open');
        risk = 45;
      } else if (t == 'WEP') {
        notes.add('q_wifi_wep');
        risk = 35;
      } else {
        notes.add('q_wifi_ok');
      }
      return QrReport(raw: s, kind: QrKind.wifi, risk: risk, notes: notes,
          details: {'network': fields['S'] ?? '?', 'security': t});
    }
    if (lower.startsWith('upi://') || lower.startsWith('raast') ||
        (RegExp(r'^000201').hasMatch(s) && s.length > 40)) {
      // UPI (India) or EMVCo merchant QR (used by Raast, many wallets).
      final details = <String, String>{};
      if (lower.startsWith('upi://')) {
        final u = Uri.tryParse(s);
        details['payee'] = u?.queryParameters['pn'] ?? '?';
        details['id'] = u?.queryParameters['pa'] ?? '?';
        if (u?.queryParameters['am'] != null) details['amount'] = u!.queryParameters['am']!;
      } else {
        final name = RegExp(r'59(\d{2})').firstMatch(s);
        if (name != null) {
          final len = int.parse(name.group(1)!);
          final start = name.end;
          if (start + len <= s.length) details['payee'] = s.substring(start, start + len);
        }
      }
      return QrReport(raw: s, kind: QrKind.payment, risk: 20, notes: const ['q_payment'], details: details);
    }
    if (RegExp(r'^(bitcoin|ethereum|litecoin|tron|usdt):', caseSensitive: false).hasMatch(s) ||
        RegExp(r'^(bc1|[13])[a-zA-HJ-NP-Z0-9]{25,62}$').hasMatch(s) ||
        RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(s)) {
      return QrReport(raw: s, kind: QrKind.crypto, risk: 35, notes: const ['q_crypto']);
    }
    if (lower.startsWith('tel:')) {
      return QrReport(raw: s, kind: QrKind.phone, risk: 5, notes: const ['q_phone'],
          details: {'number': s.substring(4)});
    }
    if (lower.startsWith('smsto:') || lower.startsWith('sms:')) {
      final parts = s.split(':');
      return QrReport(raw: s, kind: QrKind.sms, risk: 25, notes: const ['q_sms'],
          details: {'number': parts.length > 1 ? parts[1] : '?', 'text': parts.length > 2 ? parts.sublist(2).join(':') : ''});
    }
    if (lower.startsWith('mailto:') || lower.startsWith('matmsg:')) {
      return QrReport(raw: s, kind: QrKind.email, risk: 10, notes: const ['q_email']);
    }
    if (lower.startsWith('geo:')) {
      return QrReport(raw: s, kind: QrKind.geo, risk: 0, notes: const ['q_geo']);
    }
    if (lower.startsWith('begin:vcard') || lower.startsWith('mecard:')) {
      return QrReport(raw: s, kind: QrKind.contact, risk: 5, notes: const ['q_contact']);
    }
    final urls = UrlAnalyzer.extractUrls(s);
    if (urls.isNotEmpty && (urls.first.length > s.length * 0.6)) {
      final r = UrlAnalyzer.analyze(urls.first);
      return QrReport(raw: s, kind: QrKind.url, risk: r.score, url: r, notes: const ['q_url']);
    }
    final m = ScamEngine.instance.analyze(s);
    return QrReport(raw: s, kind: QrKind.text, risk: m.score, notes: const ['q_text']);
  }
}
