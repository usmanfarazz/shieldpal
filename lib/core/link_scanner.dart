import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'secure_store.dart';
import 'url_analyzer.dart';

/// Result of the "check before you open" pipeline.
class LinkScanResult {
  final UrlReport offline;
  final String? expandedUrl; // where a short link really goes
  final UrlReport? expandedReport;
  final bool? googleFlagged; // Google Safe Browsing verdict
  final bool? cloudFlagged; // Cloudflare security DNS verdict (no key needed)
  final List<String> googleThreats;
  final bool? sandboxMalicious; // urlscan.io cloud-browser verdict
  final String? sandboxScreenshot;
  final String? sandboxTitle;
  final String? sandboxFinalUrl;
  final String? sandboxReport;
  final List<String> notes;

  LinkScanResult({
    required this.offline,
    this.expandedUrl,
    this.expandedReport,
    this.googleFlagged,
    this.cloudFlagged,
    this.googleThreats = const [],
    this.sandboxMalicious,
    this.sandboxScreenshot,
    this.sandboxTitle,
    this.sandboxFinalUrl,
    this.sandboxReport,
    this.notes = const [],
  });

  int get score {
    var s = offline.score;
    if (expandedReport != null && expandedReport!.score > s) s = expandedReport!.score;
    if (googleFlagged == true) s = 100;
    if (sandboxMalicious == true) s = 100;
    if (cloudFlagged == true && s < 80) s = 80;
    return s;
  }

  Verdict get verdict => score >= 60
      ? Verdict.dangerous
      : score >= 25
          ? Verdict.suspicious
          : Verdict.safe;
}

class LinkScanner {
  static const _timeout = Duration(seconds: 12);

  /// Follows redirects of known link shorteners one hop at a time using HEAD
  /// requests, so the final (possibly bad) page is never downloaded.
  static Future<String?> expand(String url) async {
    if (kIsWeb) return null;
    var current = UrlAnalyzer.normalise(url);
    if (current == null) return null;
    final client = http.Client();
    try {
      for (var hop = 0; hop < 5; hop++) {
        final host = current!.host.toLowerCase();
        if (!UrlAnalyzer.shorteners.contains(host)) break;
        final req = http.Request('HEAD', current)..followRedirects = false;
        final res = await client.send(req).timeout(_timeout);
        final loc = res.headers['location'];
        if (loc == null || res.statusCode < 300 || res.statusCode >= 400) break;
        current = current.resolve(loc);
      }
      final out = current.toString();
      return UrlAnalyzer.normalise(url).toString() == out ? null : out;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Free reputation check, no key: asks Cloudflare's security DNS
  /// (security.cloudflare-dns.com) whether it blocks the domain as malware /
  /// phishing. Only the domain name is sent - never the full link.
  /// Returns null when the check could not run.
  static Future<bool?> cloudflareCheck(String url) async {
    final uri = UrlAnalyzer.normalise(url);
    if (uri == null || uri.host.isEmpty) return null;
    final host = uri.host;
    if (RegExp(r'^[\d.:]+$').hasMatch(host)) return null; // raw IP: nothing to look up
    try {
      final res = await http
          .get(
            Uri.https('security.cloudflare-dns.com', '/dns-query', {'name': host, 'type': 'A'}),
            headers: {'accept': 'application/dns-json'},
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final answers = (j['Answer'] as List?) ?? const [];
      final comments = ((j['Comment'] as List?) ?? const []).join(' ').toLowerCase();
      final sinkholed = answers.any((a) => (a as Map)['data'] == '0.0.0.0');
      return sinkholed || comments.contains('censored') || comments.contains('blocked');
    } catch (_) {
      return null;
    }
  }

  /// Google Safe Browsing Lookup API v4 (free key from Google Cloud Console).
  static Future<(bool?, List<String>)> googleCheck(String url) async {
    final key = await SecureStore.instance.read(SecureStore.safeBrowsingKey);
    if (key == null || key.isEmpty) return (null, <String>[]);
    try {
      final res = await http
          .post(
            Uri.parse('https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$key'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'client': {'clientId': 'shieldpal', 'clientVersion': '1.0.0'},
              'threatInfo': {
                'threatTypes': [
                  'MALWARE',
                  'SOCIAL_ENGINEERING',
                  'UNWANTED_SOFTWARE',
                  'POTENTIALLY_HARMFUL_APPLICATION',
                ],
                'platformTypes': ['ANY_PLATFORM'],
                'threatEntryTypes': ['URL'],
                'threatEntries': [
                  {'url': url},
                ],
              },
            }),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return (null, <String>[]);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final matches = (body['matches'] as List?) ?? const [];
      final types = matches
          .map((m) => (m as Map)['threatType']?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
      return (matches.isNotEmpty, types);
    } catch (_) {
      return (null, <String>[]);
    }
  }

  /// Opens the link inside urlscan.io's isolated cloud browser (never on the
  /// phone) and returns its verdict plus a screenshot of the page.
  static Future<Map<String, dynamic>?> sandboxScan(String url, {void Function(String)? onProgress}) async {
    final key = await SecureStore.instance.read(SecureStore.urlscanKey);
    if (key == null || key.isEmpty) return null;
    try {
      final submit = await http
          .post(
            Uri.parse('https://urlscan.io/api/v1/scan/'),
            headers: {'API-Key': key, 'Content-Type': 'application/json'},
            body: jsonEncode({'url': url, 'visibility': 'unlisted'}),
          )
          .timeout(_timeout);
      if (submit.statusCode != 200) return null;
      final uuid = (jsonDecode(submit.body) as Map)['uuid']?.toString();
      if (uuid == null) return null;
      // Results are usually ready after 10-30 seconds.
      for (var i = 0; i < 12; i++) {
        onProgress?.call('${(i + 1) * 5}s');
        await Future<void>.delayed(const Duration(seconds: 5));
        final r = await http
            .get(Uri.parse('https://urlscan.io/api/v1/result/$uuid/'))
            .timeout(_timeout);
        if (r.statusCode == 200) {
          final j = jsonDecode(r.body) as Map<String, dynamic>;
          final overall = ((j['verdicts'] as Map?)?['overall'] as Map?) ?? const {};
          final page = (j['page'] as Map?) ?? const {};
          return {
            'malicious': overall['malicious'] == true,
            'score': overall['score'],
            'title': page['title'],
            'finalUrl': page['url'],
            'screenshot': 'https://urlscan.io/screenshots/$uuid.png',
            'report': 'https://urlscan.io/result/$uuid/',
          };
        }
        if (r.statusCode != 404) break;
      }
    } catch (_) {}
    return null;
  }

  static Future<LinkScanResult> fullScan(String url,
      {bool deep = true, bool cloud = true, void Function(String)? onProgress}) async {
    final offline = UrlAnalyzer.analyze(url);
    final notes = <String>[];
    onProgress?.call('expand');
    final expanded = await expand(url);
    final expandedReport = expanded == null ? null : UrlAnalyzer.analyze(expanded);
    final target = expanded ?? UrlAnalyzer.normalise(url)?.toString() ?? url;
    onProgress?.call('google');
    // Cloudflare (no key) and Google (own key) run side by side.
    final results = await Future.wait<Object?>([
      googleCheck(target),
      cloud ? cloudflareCheck(target) : Future<bool?>.value(null),
    ]);
    final (gFlag, gTypes) = results[0]! as (bool?, List<String>);
    final cFlag = results[1] as bool?;
    if (gFlag == null) notes.add('n_no_google');
    Map<String, dynamic>? sandbox;
    if (deep) {
      onProgress?.call('sandbox');
      sandbox = await sandboxScan(target, onProgress: onProgress);
      if (sandbox == null) notes.add('n_no_sandbox');
    }
    return LinkScanResult(
      offline: offline,
      expandedUrl: expanded,
      expandedReport: expandedReport,
      googleFlagged: gFlag,
      cloudFlagged: cFlag,
      googleThreats: gTypes,
      sandboxMalicious: sandbox?['malicious'] as bool?,
      sandboxScreenshot: sandbox?['screenshot'] as String?,
      sandboxTitle: sandbox?['title']?.toString(),
      sandboxFinalUrl: sandbox?['finalUrl']?.toString(),
      sandboxReport: sandbox?['report'] as String?,
      notes: notes,
    );
  }
}
