import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/l10n.dart';
import 'scam_engine.dart';
import 'secure_store.dart';
import 'tips.dart';
import 'url_analyzer.dart';

class ChatMessage {
  final bool fromUser;
  final String text;
  ChatMessage(this.fromUser, this.text);
}

/// Works out which language the user typed in (so Pal AI can answer in it,
/// even when the app itself is set to another language).
class LangDetect {
  static const _romanUrdu = {
    'kya', 'hai', 'hain', 'nahi', 'nahin', 'aap', 'mujhe', 'mera', 'meri', 'mere', 'kaise', 'kaisa', 'kaisi', 'kyun',
    'kyu', 'karo', 'karna', 'kar', 'batao', 'bata', 'btao', 'mein', 'main', 'hoon', 'tum', 'tumhara', 'ka', 'ke', 'ki',
    'ko', 'se', 'par', 'abhi', 'haal', 'hal', 'theek', 'thik', 'shukriya', 'acha', 'achha', 'accha', 'bhai', 'yaar',
    'kahan', 'kaun', 'lagta', 'hota', 'hua', 'wala', 'wali', 'jaldi', 'salam', 'assalam', 'kuch', 'bohat', 'bahut',
    'sirf', 'lekin', 'magar', 'aur', 'ya', 'toh', 'to', 'koi', 'ho', 'gaya', 'gayi', 'raha', 'rahi', 'sakta', 'sakti',
    'chahiye', 'chahta', 'chahti', 'samajh', 'dobara', 'phir', 'mat', 'zaroor', 'bachao', 'bachna', 'hack',
  };
  static const _romanStrong = {
    'kya', 'hai', 'hain', 'nahi', 'nahin', 'aap', 'mujhe', 'mera', 'meri', 'kaise', 'kaisa', 'kyun', 'batao', 'haal',
    'theek', 'shukriya', 'yaar', 'bhai', 'karo', 'mein', 'hoon', 'chahiye', 'kahan', 'kaun', 'abhi',
  };

  static String detect(String text, String appLang) {
    final t = text.trim();
    if (t.isEmpty) return appLang;
    int count(RegExp r) => r.allMatches(t).length;
    if (count(RegExp(r'[ऀ-ॿ]')) > 1) return 'hi';
    if (count(RegExp(r'[ঀ-৿]')) > 1) return 'bn';
    if (count(RegExp(r'[Ѐ-ӿ]')) > 1) return 'ru';
    if (count(RegExp(r'[一-鿿]')) > 0) return 'zh';
    if (count(RegExp(r'[؀-ۿ]')) > 1) {
      return RegExp(r'[ٹڈڑںےہھگچپکی]').hasMatch(t) ? 'ur' : 'ar';
    }
    final lower = t.toLowerCase();
    final words = lower.split(RegExp(r'[^a-zçğıöşüñáéíóúãõâêô]+')).where((w) => w.isNotEmpty).toList();
    final ru = words.where(_romanUrdu.contains).length;
    final ruStrong = words.where(_romanStrong.contains).length;
    if (ruStrong >= 1 || ru >= 2) return 'rur';
    bool any(List<String> ws) => words.any(ws.contains);
    if (RegExp(r'[¿¡ñ]').hasMatch(lower) || any(['hola', 'gracias', 'cómo', 'como', 'estás', 'estas', 'ayuda'])) return 'es';
    if (any(['bonjour', 'merci', 'salut', 'comment', 'aidez', 'oui'])) return 'fr';
    if (any(['olá', 'ola', 'obrigado', 'obrigada', 'você', 'voce', 'tudo']) || lower.contains('tudo bem')) return 'pt';
    if (any(['halo', 'terima', 'kasih', 'saya', 'apa', 'kabar', 'bagaimana'])) return 'id';
    if (RegExp(r'[ğış]').hasMatch(lower) || any(['merhaba', 'teşekkür', 'nasılsın', 'selam'])) return 'tr';
    if (any(['hallo', 'danke', 'ich', 'wie', 'geht', 'bitte'])) return 'de';
    const enWords = {
      'hi', 'hello', 'hey', 'thanks', 'thank', 'what', 'how', 'why', 'when', 'where', 'who', 'is', 'are', 'was', 'the', 'my',
      'me', 'i', 'can', 'you', 'your', 'do', 'does', 'did', 'tell', 'please', 'help', 'about', 'and', 'of', 'to', 'in', 'on',
      'it', 'a', 'an', 'got', 'get', 'have', 'has', 'not', 'no', 'yes', 'with', 'for', 'this', 'that', 'will', 'would', 'should',
      'need', 'want', 'know', 'think', 'make', 'give', 'show', 'someone', 'asked', 'account', 'hacked', 'link', 'safe', 'scam',
    };
    final enHits = words.where(enWords.contains).length;
    // Two or more words with an English function word: it is English (even in a Roman Urdu app).
    if (words.length >= 2 && enHits >= 1) return 'en';
    // A lone "hi" / "hello" is ambiguous: keep the app language if it uses Latin letters.
    if (enHits >= 1) return const {'en', 'rur', 'es', 'fr', 'pt', 'id', 'tr', 'de'}.contains(appLang) ? appLang : 'en';
    // Ambiguous short text: stay in the app language if it uses Latin letters.
    return const {'en', 'rur', 'es', 'fr', 'pt', 'id', 'tr', 'de'}.contains(appLang) ? appLang : 'en';
  }

  static String englishName(String code) => switch (code) {
        'rur' => 'Roman Urdu (Urdu written in English letters)',
        'ur' => 'Urdu',
        'hi' => 'Hindi',
        'ar' => 'Arabic',
        'bn' => 'Bengali',
        'es' => 'Spanish',
        'fr' => 'French',
        'pt' => 'Portuguese',
        'id' => 'Indonesian',
        'tr' => 'Turkish',
        'ru' => 'Russian',
        'de' => 'German',
        'zh' => 'Chinese',
        _ => 'English',
      };
}

/// "Pal AI": answers questions about cyber safety and about the app.
///  1. Claude  - needs the user's own Anthropic API key.
///  2. Free AI - keyless public service (pollinations.ai), only after consent.
///  3. Offline - built-in knowledge base + the on-device scam model.
class Assistant {
  // Intent -> trigger words (several languages). Answers are translated keys.
  static const Map<String, List<String>> _intents = {
    'kb_hacked': ['hacked', 'hack ho', 'hack hogaya', 'hack ho gaya', 'account chala gaya', 'hackeado', 'piraté', 'diretas', 'هک', 'ہیک', 'हैक', 'اختراق', 'взлом', 'gehackt', '被盗', 'recover', 'recovery', 'wapas'],
    'kb_freefire': ['free fire', 'freefire', 'garena', 'diamond', 'diamonds', 'pubg', 'uc', 'roblox', 'robux', 'game account', 'fortnite', 'gaming', 'gamer', 'game'],
    'kb_otp': ['otp', 'code', 'pin', 'cvv', 'verification'],
    'kb_link': ['link', 'url', 'website', 'site', 'لنک', 'लिंक', 'enlace', 'lien', 'tautan', 'bağlantı', 'ссылк'],
    'kb_2fa': ['2fa', 'two factor', 'two-factor', 'authenticator', 'do marhala'],
    'kb_password': ['password', 'pass word', 'پاسورڈ', 'पासवर्ड', 'contraseña', 'mot de passe', 'senha', 'şifre', 'пароль', 'passwort', '密码'],
    'kb_vpn': ['vpn'],
    'kb_virus': ['virus', 'malware', 'spy', 'spyware', 'jasoos', 'وائرس', 'वायरस', 'virüs', 'вирус', 'phone slow', 'trojan'],
    'kb_voice': ['voice', 'awaaz', 'call', 'deepfake', 'clone', 'آواز', 'आवाज़', 'ai voice'],
    'kb_wifi': ['wifi', 'wi-fi', 'hotspot'],
    'kb_qr': ['qr', 'barcode'],
    'kb_number': ['number', 'kis ka number', 'whose number', 'caller', 'نمبر', 'नंबर', 'unknown number', 'anjaan'],
    'kb_pet': ['pet', 'pip', 'sick', 'beemar', 'health', 'coins'],
    'kb_live_guard': ['live guard', 'notification', 'whatsapp', 'sms', 'background'],
    'kb2_how_are_you': ['how are you', 'kya haal', 'kaise ho', 'kese ho', 'kaisa hai', 'how r u', 'whats up', "what's up", 'sup', 'haal chaal', 'como estas', 'cómo estás', 'ça va', 'comment vas', 'wie geht', 'nasılsın', 'apa kabar', 'kaise hain', 'aap kaise'],
    'kb2_who_are_you': ['who are you', 'who r u', 'your name', 'tum kaun', 'aap kaun', 'tera naam', 'tumhara naam', 'kya kar sakte', 'what can you do', 'what do you do', 'help me', 'madad', 'features'],
    'kb2_joke': ['joke', 'funny', 'mazaq', 'latifa', 'hasao', 'entertain'],
    'kb2_tip': ['tip', 'advice', 'mashwara', 'suggestion', 'salah'],
    'kb2_scam_types': ['types of scam', 'scam types', 'scams', 'kitne scam', 'fraud', 'dhoka', 'fraud kya', 'common scams'],
    'kb2_payment': ['easypaisa', 'jazzcash', 'upi', 'paytm', 'bank', 'payment', 'paisay', 'paise', 'money', 'send money', 'atm', 'card', 'sadapay', 'nayapay', 'wallet'],
    'kb2_sim': ['sim swap', 'sim block', 'sim band', 'sim', 'pta', 'cnic'],
    'kb2_phishing': ['phishing', 'fishing', 'fake page', 'fake website', 'nakli', 'jaali'],
    'kb2_social': ['instagram', 'facebook', 'tiktok', 'snapchat', 'insta', 'privacy', 'social media', 'profile', 'followers'],
    'kb2_kids': ['kids', 'child', 'children', 'bacha', 'bachay', 'parents', 'parent', 'walidain', 'teen', 'beta', 'beti'],
    'kb2_lost_phone': ['lost phone', 'phone kho', 'phone chori', 'stolen', 'phone gum', 'find my', 'phone gaya'],
    'kb2_permissions': ['permission', 'permissions', 'camera access', 'microphone', 'accessibility', 'allow'],
    'kb2_backup': ['backup', 'back up', 'restore', 'data loss'],
    'kb2_blackmail': ['blackmail', 'sextortion', 'threat', 'dhamki', 'leak photos', 'photos leak', 'nude', 'bullying', 'bully', 'harass', 'tang', 'ransom'],
    'kb2_shopping': ['olx', 'daraz', 'online shopping', 'buy online', 'seller', 'advance payment', 'fake seller', 'cash on delivery', 'cod'],
    'kb2_crypto': ['crypto', 'bitcoin', 'binance', 'invest', 'investment', 'trading', 'forex', 'profit'],
    'kb2_job': ['job', 'jobs', 'naukri', 'work from home', 'earn money', 'online earning', 'kamai'],
    'kb2_update': ['update', 'patch', 'android update'],
    'kb2_report': ['report', 'complaint', 'fia', 'police', 'cyber crime', 'cybercrime', 'shikayat', '1991', 'helpline'],
    'kb2_breach': ['breach', 'leak', 'leaked', 'pwned', 'data leak'],
    'kb2_app_use': ['how to use', 'kaise use', 'deep scan', 'live guard', 'safe link', 'kaise chalay', 'setup', 'settings', 'turn on'],
    'kb_hello': ['hi', 'hello', 'salam', 'assalam', 'hey', 'namaste', 'hola', 'bonjour', 'merhaba', 'привет', 'hallo', '你好', 'مرحبا', 'سلام', 'aoa', 'slam', 'asslam', 'hii', 'hiii', 'oye', 'selam', 'olá', 'halo'],
    'kb_thanks': ['thanks', 'thank you', 'shukriya', 'shukria', 'شکریہ', 'धन्यवाद', 'gracias', 'merci', 'obrigado', 'terima kasih', 'teşekkür', 'спасибо', 'danke', '谢谢', 'شكرا', 'thx', 'jazakallah'],
    'kb2_bye': ['bye', 'goodbye', 'allah hafiz', 'khuda hafiz', 'see you', 'ok bye', 'chalo bye'],
    'kb3_about': ['shieldpal', 'shield pal', 'this app', 'ye app', 'is app', 'app kya hai', 'what is this app', 'about app', 'about the app', 'tell me about shieldpal', 'shield pal kya'],
    'kb3_free': ['is it free', 'free hai', 'price', 'cost', 'paid', 'kitne ka', 'paise lagte', 'subscription', 'premium', 'charges'],
    'kb3_developer': ['who made', 'who created', 'developer', 'creator', 'kisne banaya', 'banane wala', 'owner of app', 'faraz', 'usman', 'who built'],
    'kb3_data': ['store my data', 'my data', 'data safe', 'privacy policy', 'tracking', 'track me', 'spy on me', 'mera data', 'data kahan', 'is my data'],
    'kb3_vpn_what': ['shield vpn', 'vpn kaam', 'vpn not working', 'vpn nahi', 'blocked site', 'blocked website', 'unblock', 'proxy', 'change country', 'location change', 'hide ip', 'ip chhupa', 'site nahi khul', 'website nahi khul', 'website open nahi'],
    'kb3_not_working': ['not working', 'nahi chal', 'nahi chalta', 'crash', 'band ho', 'bug', 'problem hai', 'issue', 'error', 'atak', 'slow', 'hang', 'khud band', 'force close'],
    'kb3_number_owner': ['sim owner', 'whose sim', 'whose number', 'kis ke naam', 'owner name', 'number ka malik', 'sim kis', 'name of number', 'caller name', 'truecaller', 'number kis ka', 'kiska number'],
    'kb3_language': ['change language', 'language change', 'zaban badal', 'urdu mein', 'hindi mein', 'speak urdu'],
    'kb3_age': ['how old', 'your age', 'kitne saal', 'umar kya'],
    'kb3_love': ['love you', 'i love', 'pyar', 'miss you', 'best friend'],
    'kb3_sad': ['i am sad', "i'm sad", 'sad hoon', 'udaas', 'depressed', 'lonely', 'akela', 'tension mein', 'dukhi'],
    'kb3_bored': ['bored', 'bore ho', 'boring', 'bor ho'],
    'kb3_greet_time': ['good morning', 'good night', 'good evening', 'good afternoon', 'subah bakhair', 'shab bakhair', 'gn', 'gm'],
    'kb3_time': ['what time', 'time kya', 'kitne baje', 'current time', 'waqt kya', 'time batao'],
    'kb3_date': ['what date', "today's date", 'date kya', 'aaj kya tareekh', 'what day', 'konsa din', 'aaj ka din', 'tareekh'],
    'kb3_weather': ['weather', 'mausam', 'barish', 'temperature'],
    'kb3_name_me': ['my name is', 'mera naam', 'i am called'],
  };

  static String offlineReply(String q, String petName, {String? replyLang}) {
    final app = L10n.current.code;
    final lang = replyLang ?? LangDetect.detect(q, app);
    String t(String k, [Map<String, Object?> a = const {}]) => trIn(lang, k, {'pet': petName, ...a});

    final urls = UrlAnalyzer.extractUrls(q);
    if (urls.isNotEmpty) {
      final r = UrlAnalyzer.analyze(urls.first);
      final reasons = r.findings.take(3).map((f) => '• ${t(f.code, {'x': f.detail})}').join('\n');
      final head = switch (r.verdict) {
        Verdict.safe => t('ai_link_safe'),
        Verdict.suspicious => t('ai_link_suspicious'),
        Verdict.dangerous => t('ai_link_dangerous'),
      };
      return '$head\n$reasons\n\n${t('ai_link_more')}'.trim();
    }
    final lower = q.toLowerCase();
    // Text that looks like a forwarded message -> run the scam model.
    if (q.length > 30 && q.split(RegExp(r'\s+')).length >= 6) {
      final m = ScamEngine.instance.analyze(q);
      if (m.score >= 30) {
        final flags = m.signals.take(3).map((s) => '• ${t(s.code)}').join('\n');
        return '${m.score >= 60 ? t('ai_msg_dangerous') : t('ai_msg_suspicious')}\n$flags';
      }
    }
    final best = bestIntent(lower);
    final math = _tryMath(q);
    if (math != null) return '🧮 $math';
    switch (best) {
      case 'kb3_time':
        final n = DateTime.now();
        return t('kb3_time_is', {'x': '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}'});
      case 'kb3_date':
        final d = DateTime.now();
        const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        return t('kb3_date_is', {'x': '${days[d.weekday - 1]}, ${d.day}/${d.month}/${d.year}'});
      case 'kb2_tip':
        return '💡 ${Tips.tipOfDay()}';
      case 'kb2_joke':
        return t('kb2_joke_${Random().nextInt(5)}');
      default:
        return t(best ?? 'kb2_fallback');
    }
  }

  static String? bestIntent(String lower) {
    String? best;
    var bestHits = 0;
    for (final e in _intents.entries) {
      final hits = e.value.where((k) => _has(lower, k)).length;
      // Longer phrases are more specific than single words.
      final weight = hits == 0 ? 0 : hits + (e.value.any((k) => k.contains(' ') && _has(lower, k)) ? 1 : 0);
      if (weight > bestHits) {
        bestHits = weight;
        best = e.key;
      }
    }
    return best;
  }

  /// Short greetings / thanks / "how are you" are answered instantly offline,
  /// so the user never waits for the internet to hear "hello".
  static bool isSmallTalk(String q) {
    final t = q.trim();
    if (t.length > 40 || t.isEmpty || UrlAnalyzer.extractUrls(t).isNotEmpty) return false;
    const quick = {
      'kb_hello', 'kb_thanks', 'kb2_how_are_you', 'kb2_bye', 'kb2_who_are_you', 'kb2_joke', 'kb2_tip', 'kb3_time', 'kb3_date',
      'kb3_age', 'kb3_love', 'kb3_bored', 'kb3_greet_time', 'kb3_name_me', 'kb3_about', 'kb3_free', 'kb3_developer', 'kb3_data',
      'kb3_vpn_what', 'kb3_number_owner', 'kb3_not_working', 'kb3_sad', 'kb3_language',
    };
    final k = bestIntent(t.toLowerCase());
    return k != null && quick.contains(k);
  }

  /// "12*5", "100 / 4 + 3", "2+2=" ... returns the answer as text, or null.
  static String? _tryMath(String q) {
    final t = q.trim().replaceAll('×', '*').replaceAll('÷', '/').replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'=\??$'), '');
    if (t.length < 3 || !RegExp(r'^[\d.+\-*/()x]+$').hasMatch(t) || !RegExp(r'[+\-*/x]').hasMatch(t.substring(1))) return null;
    final expr = t.replaceAll('x', '*');
    var pos = 0;
    late double Function() parseTerm;
    late double Function() parseFactor;
    double parseExpr() {
      var v = parseTerm();
      while (pos < expr.length && (expr[pos] == '+' || expr[pos] == '-')) {
        final op = expr[pos++];
        final r = parseTerm();
        v = op == '+' ? v + r : v - r;
      }
      return v;
    }
    parseTerm = () {
      var v = parseFactor();
      while (pos < expr.length && (expr[pos] == '*' || expr[pos] == '/')) {
        final op = expr[pos++];
        final r = parseFactor();
        v = op == '*' ? v * r : v / r;
      }
      return v;
    };
    parseFactor = () {
      if (pos < expr.length && expr[pos] == '-') {
        pos++;
        return -parseFactor();
      }
      if (pos < expr.length && expr[pos] == '(') {
        pos++;
        final v = parseExpr();
        if (pos < expr.length && expr[pos] == ')') pos++;
        return v;
      }
      final m = RegExp(r'^\d+(\.\d+)?').firstMatch(expr.substring(pos));
      if (m == null) throw const FormatException('num');
      pos += m.group(0)!.length;
      return double.parse(m.group(0)!);
    };
    try {
      final v = parseExpr();
      if (pos != expr.length || v.isNaN || v.isInfinite) return null;
      final isInt = v == v.roundToDouble() && v.abs() < 1e15;
      return '${q.trim().replaceAll(RegExp(r'=\??\s*$'), '')} = ${isInt ? v.toInt() : v.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '')}';
    } catch (_) {
      return null;
    }
  }

  static bool _has(String text, String k) {
    if (RegExp(r'^[a-z0-9 \-\x27]+$').hasMatch(k)) {
      return RegExp('(^|[^a-z0-9])${RegExp.escape(k)}([^a-z0-9]|\$)').hasMatch(text);
    }
    return text.contains(k);
  }

  static String _systemPrompt(String petName, String language) => '''
You are "Pal AI", the friendly assistant inside ShieldPal, a mobile cyber-safety app with a cute guardian pet named $petName.
Users are everyday people, many of them teenagers and gamers (Free Fire, PUBG, Roblox) and their families, often in Pakistan, India and other countries.

You are a general-purpose assistant like ChatGPT: you can chat, explain things, help with homework, translate and answer everyday questions (for example "what is Meta?"), and your special strength is staying safe online.

How to answer:
- LANGUAGE RULE (most important): reply ONLY in the language named in the "[Reply only in ...]" note at the end of the user's message, in that language's normal script. Never mix languages or scripts in one answer. English question = English answer. Roman Urdu / Hinglish (Urdu or Hindi written in English letters) = answer in Roman Urdu with Latin letters only. If there is no note, use $language.
- Be warm, natural and BRIEF: normally under 120 words and at most 5 short steps; give more only if the user asks for detail. Simple, respectful words (no slang like "babe" or "bro"). Light emojis are fine. Do not use markdown symbols such as ** or ###; use plain text and simple "1." or "•" lists.
- Safety topics: spotting scams and phishing, recovering hacked accounts (official recovery pages only), 2FA, strong passwords, safe Wi-Fi, privacy settings, what to do after clicking a bad link, sextortion and blackmail (do not pay, keep evidence, tell a trusted adult, report to the police / cybercrime authority such as FIA in Pakistan).
- Never ask for or accept passwords, OTP codes, PINs or card numbers. If the user shares one, tell them to change it right away.
- When a link or message is pasted, explain the red flags you see and advise not to open or reply. ShieldPal's offline analysis may be attached; use it.
- You can explain ShieldPal features: Deep Scan, Live Guard (catches bad links in WhatsApp/SMS notifications), Link Check with a cloud sandbox, QR scanner, Number check, Shield VPN (DNS filter that blocks dangerous websites), 2FA Vault, Family Safe-Word emojis, the "Scam or Safe?" game, and the pet that gets sick when the phone is unsafe.
- Only help with defending yourself. Politely decline requests to hack, spy on or harm others.

Facts about ShieldPal (answer questions about the app with these):
- ShieldPal is a free cyber-safety app made by Faraz Labs (Usman Faraz). It has no account, no ads, no tracking and no servers of its own; checks run on the phone.
- Shield VPN is a local VPN on the phone: it forwards traffic normally and blocks dangerous websites by DNS. It lets the user pick a DNS server. It does NOT hide the IP or change the country, so it cannot open websites that an ISP or government blocks at network level; that needs a remote VPN server (the app can run the user's own WireGuard config).
- Number Check shows country, number type, network and warning signs, plus the name from the user's own contacts. The registered owner of a SIM is private (only the operator and police can trace it); the app does not and cannot show it.
- Live Guard reads new notifications on the device to catch scam links and messages. Deep Scan audits the phone's security. Link Check, Message Check and Safe QR use offline rules plus Cloudflare / Google / urlscan cloud checks.
- The user can change the pet, its voice, the language and the DNS server in Settings.''';

  static List<Map<String, dynamic>> _toApiMessages(List<ChatMessage> history, {int keep = 14, String? language}) {
    final messages = <Map<String, dynamic>>[];
    for (final m in history.where((m) => m.text.trim().isNotEmpty).toList().reversed.take(keep).toList().reversed) {
      final role = m.fromUser ? 'user' : 'assistant';
      if (messages.isNotEmpty && messages.last['role'] == role) {
        messages.last['content'] = '${messages.last['content']}\n\n${m.text}';
      } else {
        messages.add({'role': role, 'content': m.text});
      }
    }
    while (messages.isNotEmpty && messages.first['role'] != 'user') {
      messages.removeAt(0);
    }
    if (messages.isEmpty) return messages;
    // Attach the offline link analysis to the latest user message.
    final last = messages.last['content'] as String;
    final urls = UrlAnalyzer.extractUrls(last);
    if (urls.isNotEmpty) {
      final r = UrlAnalyzer.analyze(urls.first);
      messages.last['content'] =
          '$last\n\n[ShieldPal offline analysis of ${urls.first}: risk ${r.score}/100, flags: ${r.findings.map((f) => f.code).join(', ')}]';
    }
    // Repeat the language rule right next to the question: models obey it far better there.
    if (language != null && language.isNotEmpty) {
      messages.last['content'] = '${messages.last['content']}\n\n[Reply only in $language. Do not mix languages or scripts.]';
    }
    return messages;
  }

  static Future<bool> hasClaudeKey() async => ((await SecureStore.instance.read(SecureStore.claudeKey)) ?? '').isNotEmpty;

  /// Free keyless AI (pollinations.ai). Returns null on any problem so the
  /// caller can fall back to the offline brain.
  static Future<String?> freeOnline(List<ChatMessage> history, String petName, String languageName) async {
    final messages = _toApiMessages(history, keep: 12, language: languageName);
    if (messages.isEmpty) return null;
    final payload = jsonEncode({
      'model': 'openai-fast',
      'max_tokens': 500,
      'messages': [
        {'role': 'system', 'content': _systemPrompt(petName, languageName)},
        ...messages,
      ],
    });
    // The free service limits rapid requests (HTTP 429): wait a moment and retry twice.
    http.Response? res;
    for (var attempt = 0; attempt < 3; attempt++) {
      res = await http
          .post(Uri.parse('https://text.pollinations.ai/openai'),
              headers: {'content-type': 'application/json'}, body: payload)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) break;
      if (res.statusCode != 429 && res.statusCode < 500) return null;
      await Future<void>.delayed(Duration(seconds: 2 + attempt * 2));
    }
    if (res == null || res.statusCode != 200) return null;
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    var text = (((body['choices'] as List?)?.firstOrNull as Map?)?['message'] as Map?)?['content']?.toString().trim() ?? '';
    // The free service sometimes appends an advert; keep only the answer.
    final ad = text.toLowerCase().indexOf('support pollinations');
    if (ad > 0) text = text.substring(0, ad).trim().replaceAll(RegExp(r'[-—_*\s]+$'), '');
    return text.isEmpty ? null : cleanMarkdown(text);
  }

  /// The chat shows plain text, so turn markdown into simple text:
  /// **bold** -> bold, "### Title" -> Title, "* item" -> "• item".
  static String cleanMarkdown(String t) {
    var out = t.replaceAll(RegExp(r'\*\*|__'), '');
    out = out.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
    out = out.replaceAllMapped(RegExp(r'^(\s*)[*-]\s+', multiLine: true), (m) => '${m[1]}• ');
    out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return out.trim();
  }

  /// Sends the conversation to Claude. Returns null when no API key is set.
  static Future<String?> online(List<ChatMessage> history, String petName, String languageName) async {
    final key = await SecureStore.instance.read(SecureStore.claudeKey);
    if (key == null || key.isEmpty) return null;
    final messages = _toApiMessages(history, language: languageName);
    if (messages.isEmpty) return null;

    final res = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'content-type': 'application/json',
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
          },
          body: jsonEncode({
            'model': 'claude-sonnet-5-5',
            'max_tokens': 1500,
            'system': _systemPrompt(petName, languageName),
            'messages': messages,
          }),
        )
        .timeout(const Duration(seconds: 90));

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final err = (body['error'] as Map?)?['message']?.toString() ?? 'HTTP ${res.statusCode}';
      throw Exception(err);
    }
    if (body['stop_reason'] == 'refusal') return tr('ai_refusal');
    final text = ((body['content'] as List?) ?? const [])
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'].toString())
        .join('\n')
        .trim();
    return text.isEmpty ? tr('ai_empty') : cleanMarkdown(text);
  }
}
