import 'dart:math';

import 'quiz_data.dart';

/// Endless "Scam or Safe?" deck builder. Every game mixes the hand-written
/// cards in quiz_data.dart with freshly generated ones (brands, amounts,
/// domains and wording change each time) and keeps scam / safe about 50:50,
/// never more than two of the same answer in a row, so "always press Safe"
/// never works.
class QuizGenerator {
  static final Set<String> _seen = {};

  static const _brands = [
    'Garena', 'Netflix', 'Daraz', 'Easypaisa', 'JazzCash', 'HBL', 'UBL', 'Meezan Bank', 'Binance', 'Instagram',
    'Facebook', 'WhatsApp', 'TikTok', 'PUBG', 'Amazon', 'PayPal', 'Google', 'Apple', 'Telegram', 'Spotify', 'Steam',
    'Roblox', 'Discord', 'K-Electric', 'SNGPL', 'NADRA', 'FBR', 'TCS', 'Leopards', 'DHL', 'Uber', 'Careem',
    'Foodpanda', 'Samsung', 'Zong', 'Telenor', 'Jazz', 'Ufone', 'YouTube', 'Snapchat',
  ];
  static const _words = ['verify', 'support', 'secure', 'login', 'claim', 'bonus', 'reward', 'help', 'billing', 'update', 'official', 'event', 'gift', 'recover'];
  static const _tlds = ['xyz', 'top', 'club', 'online', 'site', 'live', 'click', 'icu', 'work', 'shop', 'buzz', 'cfd'];
  static const _things = ['diamonds', 'robux', 'UC', 'coins', 'elite pass', 'skins', 'gems', 'followers'];
  static const _names = ['Ahmed', 'Sara', 'Ali', 'Fatima', 'Hamza', 'Ayesha', 'Usman', 'Zainab', 'Bilal', 'Hira', 'Omar', 'Maryam'];
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _cities = ['lahore', 'karachi', 'islamabad', 'multan', 'peshawar', 'quetta', 'faisalabad'];
  static const _safeSites = ['maps.google.com', 'youtube.com', 'wikipedia.org', 'docs.google.com', 'github.com', 'whatsapp.com'];

  static T _pick<T>(List<T> l, Random r) => l[r.nextInt(l.length)];
  static String _digits(Random r, int n) => List.generate(n, (_) => r.nextInt(10)).join();
  static String _amount(Random r) => '${(1 + r.nextInt(99)) * 500}';

  static String _dom(String brand, Random r) {
    final b = brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final w = _pick(_words, r);
    final t = _pick(_tlds, r);
    return switch (r.nextInt(4)) {
      0 => '$b-$w.$t',
      1 => '$w-$b.$t',
      2 => '${b.replaceAll('o', '0').replaceAll('i', '1')}-$w.$t',
      _ => '$b.$w-${r.nextInt(99)}.$t',
    };
  }

  static QuizCard _scam(Random r) {
    final b = _pick(_brands, r);
    final d = _dom(b, r);
    final n = _amount(r);
    final fee = '${(1 + r.nextInt(9)) * 250}';
    final sender = r.nextBool()
        ? b
        : (r.nextBool() ? 'Unknown' : '+${[92, 44, 1, 880, 234, 212][r.nextInt(6)]} ${_digits(r, 3)} ${_digits(r, 7)}');
    final t = _pick(_things, r);
    final name = _pick(_names, r);
    final options = <QuizCard Function()>[
      () => QuizCard(sender, '$b: Your account is suspended. Verify within 24h: $d', true, 'qx_fake_domain'),
      () => QuizCard(sender, '$b: Congratulations! You won Rs $n. Claim in 1 hour: $d', true, 'qx_prize'),
      () => QuizCard(sender, 'Dear customer, your $b account will be closed in ${2 + r.nextInt(20)} hours. Update details at $d', true, 'qx_threat'),
      () => QuizCard(sender, 'Free $t for $b players!! Just login at $d 😍', true, 'qx_fake_domain'),
      () => QuizCard(sender, 'Aap ka $b account block ho gaya hai. Abhi verify karein: $d', true, 'qx_fake_domain'),
      () => QuizCard(sender, 'Urgent: reply with the 6-digit code you just received to confirm your $b account.', true, 'qx_code_back'),
      () => QuizCard(sender, 'Hi, I am from $b support. Please share your OTP so we can fix the problem.', true, 'qx_otp'),
      () => QuizCard(sender, 'Mubarak! $b cashback Rs $n select hua hai. Receive karne ke liye Rs $fee fee jama karwayein.', true, 'qx_prize'),
      () => QuizCard('HR Team', 'Part-time job: earn Rs $n daily from your phone. Registration fee Rs $fee via Easypaisa.', true, 'qx_job'),
      () => QuizCard('+${[44, 971, 1, 966][r.nextInt(4)]} ${_digits(r, 10)}', 'Mom, this is my new number, my phone broke. Please send Rs $n urgently, don\'t tell dad.', true, 'qx_family_imp'),
      () => QuizCard('Friend', 'Bhai mera account hack ho gaya, tum $b ka code bhej do verify ke liye, jaldi!', true, 'qx_code_back'),
      () => QuizCard('Unknown', 'Mod APK $b unlimited $t download: $d/${_digits(r, 3)}.apk', true, 'qx_apk'),
      () => QuizCard('Windows Alert', 'Your phone is infected with ${3 + r.nextInt(30)} viruses! Call $b support now: +1 800 555 ${_digits(r, 4)}', true, 'qx_tech_support'),
      () => QuizCard('Crypto Club', 'Invest \$${(1 + r.nextInt(9)) * 50} and get \$${(1 + r.nextInt(9)) * 1000} in ${3 + r.nextInt(10)} days. Guaranteed profit!', true, 'qx_too_good'),
      () => QuizCard('Scan me', 'QR on a parking meter: pay your fine at $d', true, 'qx_quishing'),
      () => QuizCard(name, 'Hey it\'s me $name, send me your $b login real quick, I need to check something.', true, 'qx_password'),
      () => QuizCard(sender, '$b: Payment failed. Update your card within 12 hours or the account will be deleted: $d', true, 'qx_threat'),
      () => QuizCard('Bank', 'Main bank se bol raha hun, aapka card block hone wala hai. Card ke peechay wale 3 number batayein.', true, 'qx_cvv'),
    ];
    return _pick(options, r)();
  }

  static QuizCard _safe(Random r) {
    final b = _pick(_brands, r);
    final name = _pick(_names, r);
    final amt = _amount(r);
    final bal = '${1000 + r.nextInt(90000)}';
    final day = _pick(_days, r);
    final id = _digits(r, 6);
    final site = _pick(_safeSites, r);
    final options = <QuizCard Function()>[
      () => QuizCard(b, 'Your $b order #$id has been shipped and will arrive on $day.', false, 'qx_receipt'),
      () => QuizCard(b, 'Your $b code is ${_digits(r, 6)}. Never share this code with anyone.', false, 'qx_real_otp'),
      () => QuizCard(b, 'Rs $amt received from $name. Available balance Rs $bal.', false, 'qx_receipt'),
      () => QuizCard('Ammi', 'Beta ${_pick(['khana', 'dinner', 'lunch'], r)} kha liya? ${_pick(['Jaldi ghar aana.', 'Dawai le lena.', 'Raat ko bahar mat rehna.'], r)}', false, 'qx_normal'),
      () => QuizCard(name, 'Meeting $day at ${1 + r.nextInt(11)}:${['00', '30'][r.nextInt(2)]}, see you there.', false, 'qx_normal'),
      () => QuizCard(name, 'Happy birthday! 🎂 Party is on $day, don\'t be late.', false, 'qx_normal'),
      () => QuizCard(b, 'New login from a new device. If this wasn\'t you, open the $b app and secure your account.', false, 'qx_inapp'),
      () => QuizCard(b, 'Your $b bill of Rs $amt is due on $day. Pay it inside the official $b app.', false, 'qx_inapp'),
      () => QuizCard('Cousin', 'Shaadi ki location: https://$site/?q=${_pick(_cities, r)}', false, 'qx_known_site'),
      () => QuizCard('Teacher', 'Assignment ${1 + r.nextInt(9)} deadline is $day. Submit it on the school portal.', false, 'qx_normal'),
      () => QuizCard('Dad', _pick(['Running late, start dinner without me.', 'I will pick you up at 5.', 'Call me when you reach.'], r), false, 'qx_normal'),
      () => QuizCard(b, 'Your $b verification code is ${_digits(r, 4)}. It expires in 10 minutes. We will never ask for it by phone.', false, 'qx_real_otp'),
      () => QuizCard('Class group', 'Notes for chapter ${1 + r.nextInt(12)} are on the school drive: https://docs.google.com/', false, 'qx_known_site'),
    ];
    return _pick(options, r)();
  }

  /// Fresh deck of [n] cards with a balanced, shuffled scam / safe pattern.
  static List<QuizCard> deck(int n, {Random? random}) {
    final r = random ?? Random();
    final pattern = List<bool>.generate(n, (i) => i < (n + 1) ~/ 2);
    do {
      pattern.shuffle(r);
    } while (_hasTriple(pattern));
    final fixedScam = quizCards.where((c) => c.isScam).toList()..shuffle(r);
    final fixedSafe = quizCards.where((c) => !c.isScam).toList()..shuffle(r);
    final out = <QuizCard>[];
    for (final scam in pattern) {
      QuizCard? card;
      for (var tries = 0; tries < 12 && card == null; tries++) {
        final pool = scam ? fixedScam : fixedSafe;
        final c = r.nextBool() && pool.isNotEmpty ? pool.removeLast() : (scam ? _scam(r) : _safe(r));
        if (_seen.add(c.message)) card = c;
      }
      out.add(card ?? (scam ? _scam(r) : _safe(r)));
    }
    if (_seen.length > 400) _seen.clear();
    return out;
  }

  static bool _hasTriple(List<bool> p) {
    for (var i = 2; i < p.length; i++) {
      if (p[i] == p[i - 1] && p[i] == p[i - 2]) return true;
    }
    return false;
  }
}
