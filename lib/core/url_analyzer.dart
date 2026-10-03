// Offline link analysis. Works without internet: looks at the shape of a
// link and flags the tricks phishing sites use (look-alike brand names,
// throwaway domains, raw IP addresses, hidden redirects and so on).

enum Verdict { safe, suspicious, dangerous }

class Finding {
  final String code; // localisation key, e.g. "f_lookalike"
  final int weight;
  final String detail;
  const Finding(this.code, this.weight, [this.detail = '']);
}

class UrlReport {
  final String url;
  final String host;
  final int score; // 0 = clean, 100 = certainly bad
  final List<Finding> findings;
  UrlReport(this.url, this.host, this.score, this.findings);

  Verdict get verdict => score >= 60
      ? Verdict.dangerous
      : score >= 25
          ? Verdict.suspicious
          : Verdict.safe;
}

class UrlAnalyzer {
  static final RegExp _urlPattern = RegExp(
    r'''((?:https?://|www\.)[^\s<>"'()]+|\b[a-z0-9][a-z0-9-]{1,62}(?:\.[a-z0-9-]{2,63})*\.(?:com|net|org|xyz|top|site|online|club|live|info|link|click|shop|store|app|io|me|ly|gl|cc|tk|ml|ga|cf|gq|pk|in|co|ru|cn|icu|buzz|rest|cfd|sbs|vip|win|bid|loan|work|fun|space|website|pw|su)(?:/[^\s<>"'()]*)?)''',
    caseSensitive: false,
  );

  /// Finds every link inside a piece of text (SMS, WhatsApp message, email...).
  static List<String> extractUrls(String text) {
    final out = <String>{};
    for (final m in _urlPattern.allMatches(text)) {
      var u = m.group(0)!.trim();
      u = u.replaceAll(RegExp(r'[.,!?;:]+$'), '');
      if (u.contains('@') && !u.contains('/')) continue; // e-mail address
      out.add(u);
    }
    return out.toList();
  }

  // Brands that scammers love to copy. Key = brand word, value = real domains.
  static const Map<String, List<String>> brands = {
    'garena': ['garena.com', 'ff.garena.com'],
    'freefire': ['ff.garena.com', 'garena.com'],
    'free-fire': ['ff.garena.com', 'garena.com'],
    'pubg': ['pubgmobile.com', 'pubg.com', 'midasbuy.com'],
    'midasbuy': ['midasbuy.com'],
    'roblox': ['roblox.com'],
    'robux': ['roblox.com'],
    'fortnite': ['fortnite.com', 'epicgames.com'],
    'epicgames': ['epicgames.com'],
    'steam': ['steampowered.com', 'steamcommunity.com'],
    'minecraft': ['minecraft.net'],
    'tiktok': ['tiktok.com'],
    'instagram': ['instagram.com'],
    'facebook': ['facebook.com', 'fb.com', 'fb.me'],
    'whatsapp': ['whatsapp.com', 'wa.me', 'whatsapp.net'],
    'telegram': ['telegram.org', 't.me'],
    'snapchat': ['snapchat.com'],
    'google': ['google.com', 'goo.gl', 'g.co', 'google.com.pk'],
    'gmail': ['google.com', 'gmail.com'],
    'youtube': ['youtube.com', 'youtu.be'],
    'microsoft': ['microsoft.com', 'live.com', 'office.com'],
    'apple': ['apple.com', 'icloud.com'],
    'icloud': ['icloud.com', 'apple.com'],
    'netflix': ['netflix.com'],
    'amazon': ['amazon.com', 'amazon.in', 'amazon.ae'],
    'paypal': ['paypal.com'],
    'binance': ['binance.com'],
    'easypaisa': ['easypaisa.com.pk'],
    'jazzcash': ['jazzcash.com.pk'],
    'jazz': ['jazz.com.pk'],
    'telenor': ['telenor.com.pk', 'telenor.com'],
    'zong': ['zong.com.pk'],
    'ufone': ['ufone.com'],
    'hbl': ['hbl.com'],
    'meezan': ['meezanbank.com'],
    'ubl': ['ubldigital.com'],
    'bisp': ['bisp.gov.pk'],
    'ehsaas': ['pass.gov.pk', 'bisp.gov.pk'],
    'nadra': ['nadra.gov.pk'],
    'fbr': ['fbr.gov.pk'],
    'paytm': ['paytm.com'],
    'phonepe': ['phonepe.com'],
    'sbi': ['onlinesbi.sbi', 'sbi.co.in'],
    'dhl': ['dhl.com'],
    'fedex': ['fedex.com'],
    'tcs': ['tcsexpress.com', 'tcs.com.pk'],
    'meta': ['meta.com', 'facebook.com'],
    'leopards': ['leopardscourier.com'],
    'careem': ['careem.com'],
    'foodpanda': ['foodpanda.pk', 'foodpanda.com'],
    'olx': ['olx.com.pk', 'olx.com'],
    'daraz': ['daraz.pk'],
    'aliexpress': ['aliexpress.com'],
    'shein': ['shein.com'],
  };

  // Top-level domains that are free or very cheap and heavily abused.
  static const Set<String> riskyTlds = {
    'xyz', 'top', 'tk', 'ml', 'ga', 'cf', 'gq', 'icu', 'buzz', 'rest', 'cfd',
    'sbs', 'click', 'link', 'live', 'online', 'site', 'club', 'vip', 'win',
    'bid', 'loan', 'work', 'fun', 'space', 'website', 'pw', 'su', 'monster',
    'cyou', 'quest', 'bar', 'zip', 'mov',
  };

  static const Set<String> shorteners = {
    'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'is.gd', 'cutt.ly', 'rb.gy',
    'ow.ly', 'shorturl.at', 'tiny.cc', 'rebrand.ly', 'bl.ink', 'v.gd',
    's.id', 'shorturl.asia', 't.ly', 'lnkd.in', 'surl.li', 'urlz.fr',
  };

  static const List<String> baitWords = [
    'free', 'diamond', 'diamonds', 'robux', 'uc', 'skin', 'skins', 'gift',
    'giveaway', 'reward', 'prize', 'winner', 'bonus', 'claim', 'verify',
    'verification', 'login', 'signin', 'sign-in', 'account', 'secure',
    'update', 'unlock', 'suspend', 'suspended', 'blocked', 'confirm',
    'wallet', 'airdrop', 'otp', 'kyc', 'refund', 'inaam', 'muft', 'lucky',
    'spin', 'hack', 'generator', 'mod', 'unlimited', 'password', 'recovery',
  ];

  // Popular, trusted sites. A clean link on these gets no penalty.
  static const Set<String> trusted = {
    'google.com', 'youtube.com', 'wikipedia.org', 'facebook.com',
    'instagram.com', 'whatsapp.com', 'wa.me', 'microsoft.com', 'apple.com',
    'amazon.com', 'github.com', 'linkedin.com', 'x.com', 'twitter.com',
    'reddit.com', 'tiktok.com', 'netflix.com', 'garena.com', 'roblox.com',
    'daraz.pk', 'gov.pk', 'bbc.com', 'cnn.com', 'dawn.com', 'paypal.com',
    'youtu.be', 'play.google.com', 'apps.apple.com', 'telegram.org', 't.me',
    'stackoverflow.com', 'medium.com', 'zoom.us', 'spotify.com',
  };

  static String _registrable(String host) {
    final parts = host.split('.');
    if (parts.length <= 2) return host;
    final last2 = parts.sublist(parts.length - 2).join('.');
    // Handle second-level country domains like com.pk, co.uk, gov.pk
    const slds = {'com', 'co', 'gov', 'org', 'net', 'edu', 'ac'};
    if (parts[parts.length - 1].length == 2 && slds.contains(parts[parts.length - 2])) {
      return parts.sublist(parts.length - 3).join('.');
    }
    return last2;
  }

  /// Brand names that appear in a host. Short names (hbl, ubl, dhl...) must be
  /// a whole label part so that "public.com" does not match "ubl".
  static List<String> brandsIn(String host) {
    final tokens = host.split(RegExp(r'[.\-_]'));
    final compact = host.replaceAll(RegExp(r'[.\-_]'), '');
    final out = <String>[];
    for (final b in brands.keys) {
      final bc = b.replaceAll('-', '');
      final hit = bc.length <= 4
          ? tokens.any((t) => t.startsWith(bc) && _shortBrandPrefix(t, bc))
          : compact.contains(bc);
      if (hit) out.add(b);
    }
    // Longest first so "jazzcash" wins over "jazz".
    out.sort((a, b) => b.length.compareTo(a.length));
    return out;
  }

  static bool _shortBrandPrefix(String token, String brand) {
    if (token == brand) return true;
    final rest = token.substring(brand.length);
    const suffixes = ['bank', 'online', 'login', 'pk', 'app', 'help', 'support', 'verify', 'secure', 'cash', 'card', 'net', 'web'];
    return suffixes.any(rest.startsWith) || RegExp(r'^\d+$').hasMatch(rest);
  }

  static bool _hostIs(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

  static Uri? normalise(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(s)) {
      s = 'http://$s';
    }
    try {
      final u = Uri.parse(s);
      if (u.host.isEmpty) return null;
      return u;
    } catch (_) {
      return null;
    }
  }

  static UrlReport analyze(String raw) {
    final uri = normalise(raw);
    if (uri == null) {
      return UrlReport(raw, '', 30, [const Finding('f_unreadable', 30)]);
    }
    final host = uri.host.toLowerCase();
    final full = raw.toLowerCase();
    final findings = <Finding>[];
    final reg = _registrable(host);

    // 1. Raw IP address instead of a name.
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) || host.contains(':')) {
      findings.add(const Finding('f_ip_host', 35));
    }
    // 2. Punycode / non-latin look-alike letters (xn--).
    if (host.contains('xn--') || RegExp(r'[^\x00-\x7F]').hasMatch(raw.split('/').take(3).join('/'))) {
      findings.add(const Finding('f_punycode', 40));
    }
    // 3. "@" trick: http://google.com@evil.site
    if (uri.userInfo.isNotEmpty) {
      findings.add(const Finding('f_at_trick', 45));
    }
    // 4. Not encrypted.
    if (uri.scheme == 'http' && raw.toLowerCase().startsWith('http://')) {
      findings.add(const Finding('f_no_https', 10));
    }
    // 5. Risky / free top-level domain.
    final tld = host.split('.').last;
    if (riskyTlds.contains(tld)) {
      findings.add(Finding('f_risky_tld', 20, '.$tld'));
    }
    // 6. Brand look-alike: brand word in host but not the real domain.
    final matched = brandsIn(host);
    if (matched.isNotEmpty) {
      final legit = matched.any((b) => brands[b]!.any((d) => _hostIs(host, d)));
      if (!legit) findings.add(Finding('f_lookalike', 50, matched.first));
    }
    // 6b. Brand name hidden in the path of a site that isn't the brand.
    if (matched.isEmpty) {
      final path = '${uri.path} ${uri.query}'.toLowerCase();
      final inPath = brands.keys.where((b) => b.length > 4 && path.contains(b)).toList();
      if (inPath.isNotEmpty && !trusted.any((t) => _hostIs(host, t))) {
        findings.add(Finding('f_brand_in_path', 25, inPath.first));
      }
    }
    // 7. Typo-squatting with digits (g00gle, faceb00k, paypa1).
    final deDigit = host
        .replaceAll('0', 'o')
        .replaceAll('1', 'l')
        .replaceAll('3', 'e')
        .replaceAll('5', 's')
        .replaceAll('rn', 'm');
    if (deDigit != host && matched.isEmpty) {
      final fake = brandsIn(deDigit);
      if (fake.isNotEmpty) findings.add(Finding('f_typosquat', 50, fake.first));
    }
    // 8. Link shortener hides where it really goes.
    if (shorteners.contains(host) || shorteners.contains(reg)) {
      findings.add(const Finding('f_shortener', 15));
    }
    // 9. Too many sub-domains (login.secure.account.verify.example.xyz).
    final dots = '.'.allMatches(host).length;
    if (dots >= 4) findings.add(const Finding('f_many_subdomains', 15));
    // 10. Many hyphens in the name.
    if ('-'.allMatches(reg).length >= 2) findings.add(const Finding('f_hyphens', 10));
    // 11. Bait words in the address.
    final hits = baitWords.where((w) => RegExp('(^|[^a-z])$w([^a-z]|\$)').hasMatch(full)).toList();
    if (hits.isNotEmpty) {
      findings.add(Finding('f_bait_words', (hits.length * 8).clamp(8, 30), hits.take(4).join(', ')));
    }
    // 12. Very long address.
    if (raw.length > 120) findings.add(const Finding('f_long_url', 8));
    // 13. Direct download of an app/executable.
    if (RegExp(r'\.(apk|exe|scr|bat|msi|xapk|apks|jar|vbs|ps1)(\?|$)').hasMatch(uri.path.toLowerCase())) {
      findings.add(const Finding('f_download', 40));
    }
    // 14. Unusual port.
    if (uri.hasPort && uri.port != 80 && uri.port != 443) {
      findings.add(const Finding('f_odd_port', 15));
    }
    // 15. Data / javascript schemes.
    if (uri.scheme == 'data' || uri.scheme == 'javascript') {
      findings.add(const Finding('f_script_scheme', 70));
    }

    var score = findings.fold<int>(0, (a, f) => a + f.weight);
    final isTrusted = trusted.any((t) => _hostIs(host, t)) ||
        host.endsWith('.gov.pk') || host.endsWith('.gov');
    if (isTrusted && findings.every((f) => f.code == 'f_no_https' || f.code == 'f_long_url')) {
      score = 0;
    }
    return UrlReport(raw, host, score.clamp(0, 100), findings);
  }
}
