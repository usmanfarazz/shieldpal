import 'dart:math';

import 'scam_dataset.dart';
import 'url_analyzer.dart';

/// A tiny Naive Bayes text classifier trained on-device from [scamDataset].
/// It is ShieldPal's own "trained AI": it learns which words appear in scams
/// and which appear in normal chats, in many languages.
class NaiveBayes {
  final Map<String, int> _scam = {};
  final Map<String, int> _ham = {};
  int _scamDocs = 0, _hamDocs = 0, _scamWords = 0, _hamWords = 0;
  final Set<String> _vocab = {};

  static List<String> tokenize(String text) {
    final lower = text.toLowerCase();
    final words = lower
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.length > 1 || RegExp(r'\p{Script=Han}', unicode: true).hasMatch(w))
        .map((w) => RegExp(r'^\d{4,}$').hasMatch(w) ? '<num>' : w)
        .toList();
    final out = <String>[...words];
    for (var i = 0; i + 1 < words.length; i++) {
      out.add('${words[i]}_${words[i + 1]}');
    }
    if (UrlAnalyzer.extractUrls(text).isNotEmpty) out.add('<url>');
    return out;
  }

  void train(Iterable<(String, int)> data) {
    for (final (text, label) in data) {
      final toks = tokenize(text);
      if (label == 1) {
        _scamDocs++;
        for (final t in toks) {
          _scam[t] = (_scam[t] ?? 0) + 1;
          _scamWords++;
        }
      } else {
        _hamDocs++;
        for (final t in toks) {
          _ham[t] = (_ham[t] ?? 0) + 1;
          _hamWords++;
        }
      }
      _vocab.addAll(toks);
    }
  }

  /// Probability (0..1) that [text] is a scam.
  double predict(String text) {
    final toks = tokenize(text).where(_vocab.contains).toList();
    if (toks.isEmpty) return 0.5;
    final v = _vocab.length;
    var logScam = log(_scamDocs / (_scamDocs + _hamDocs));
    var logHam = log(_hamDocs / (_scamDocs + _hamDocs));
    for (final t in toks) {
      logScam += log(((_scam[t] ?? 0) + 1) / (_scamWords + v));
      logHam += log(((_ham[t] ?? 0) + 1) / (_hamWords + v));
    }
    final diff = (logHam - logScam).clamp(-50.0, 50.0);
    return 1 / (1 + exp(diff));
  }

  /// How many known words the message shares with the training set.
  int knownTokens(String text) => tokenize(text).where(_vocab.contains).length;
}

class Signal {
  final String code; // localisation key
  final int weight;
  const Signal(this.code, this.weight);
}

class MessageReport {
  final String text;
  final int score;
  final double aiProbability;
  final List<Signal> signals;
  final List<UrlReport> links;
  MessageReport(this.text, this.score, this.aiProbability, this.signals, this.links);

  Verdict get verdict => score >= 60
      ? Verdict.dangerous
      : score >= 30
          ? Verdict.suspicious
          : Verdict.safe;
}

class ScamEngine {
  ScamEngine._() {
    _model.train(scamDataset);
  }
  static final ScamEngine instance = ScamEngine._();
  final NaiveBayes _model = NaiveBayes();

  /// Teach the on-device model from the user's own verdicts (1 = scam, 0 = safe).
  /// Own examples count three times so a few corrections already change results.
  void learn(String text, int label) {
    for (var i = 0; i < 3; i++) {
      _model.train([(text, label)]);
    }
  }

  void learnAll(Iterable<(String, int)> examples) {
    for (final e in examples) {
      learn(e.$1, e.$2);
    }
  }

  // Keyword groups in many languages. Each hit adds weight.
  static const Map<String, List<String>> _groups = {
    's_otp': [
      'otp', 'login code', 'the code', 'woh code', 'pin', 'cvv', 'password', 'passcode', 'verification code',
      'کوڈ', 'پن', 'او ٹی پی', 'पिन', 'ओटीपी', 'कोड', 'رمز', 'código', 'kode',
      'şifre', 'mot de passe', 'senha', 'contraseña',
    ],
    's_urgent': [
      'urgent', 'immediately', 'today', 'within 24 hours', 'expire', 'expires',
      'last chance', 'right now', 'foran', 'abhi', 'jaldi', 'aaj raat', 'turant',
      'فوراً', 'جلدی', 'तुरंत', 'عاجل', 'فورا', 'urgente', 'inmediatamente',
      'segera', 'hemen', 'immédiatement', 'imediatamente',
    ],
    's_threat': [
      'blocked', 'suspended', 'deleted', 'banned', 'locked', 'disabled', 'arrest',
      'legal action', 'block', 'band ho', 'band kar', 'giraftari', 'police',
      'بند', 'گرفتاری', 'बंद', 'गिरफ्तार', 'إيقاف', 'bloqueada', 'bloqueado',
      'diblokir', 'askıya', 'bloqué', 'bloqueada',
    ],
    's_prize': [
      'won', 'winner', 'prize', 'lottery', 'congratulations', 'lucky', 'reward',
      'gift', 'free gift', 'for free', 'giveaway', 'inaam', 'mubarak ho', 'muft', 'jeeto',
      'انعام', 'مبارک ہو', 'इनाम', 'लॉटरी', 'बधाई', 'مبروك', 'جائزة', 'ganado',
      'premio', 'prêmio', 'hadiah', 'ödül', 'gagné', 'diamonds', 'robux', 'uc',
    ],
    's_money': [
      'send money', 'transfer', 'fee', 'deposit', 'pay', 'payment', 'easypaisa kar',
      'paise bhejo', 'paise bhej', 'raqam', 'jama karwa', 'bitcoin', 'usdt', 'btc',
      'پیسے بھیج', 'رقم', 'पैसे भेज', 'फीस', 'أرسل', 'envío', 'pague', 'kirim',
    ],
    's_credentials': [
      'login', 'log in', 'sign in', 'verify your account', 'confirm your identity',
      'enter your password', 'username and password', 'cnic', 'card number',
      'bank details', 'id aur password', 'account details', 'شناختی کارڈ',
      'بيانات بطاقتك', 'datos', 'dados', 'kart bilgilerinizi',
    ],
    's_impersonation': [
      'bank se', 'from bank', 'customer care', 'support team', 'official',
      'fia', 'pta', 'nadra', 'bisp', 'ehsaas', 'garena', 'microsoft support',
      'meta support', 'apple support', 'mera naya number', 'my new number',
      'main musibat', 'in trouble', 'kisi ko mat batana', 'do not tell anyone',
      'کسی کو مت بتانا', 'مشکل میں',
    ],
    's_secret_code_back': [
      'by mistake', 'galti se', 'send it back', 'wapas bhej', 'mujhe bhej dein',
      'عن طريق الخطأ',
    ],
  };

  static const Map<String, int> _weights = {
    's_otp': 18,
    's_urgent': 12,
    's_threat': 14,
    's_prize': 14,
    's_money': 14,
    's_credentials': 18,
    's_impersonation': 12,
    's_secret_code_back': 30,
  };

  // A real bank OTP usually says "do not share" - that lowers the risk.
  static final RegExp _safeOtpNotice = RegExp(
    r"(do not share|don't share|never share|never ask|will not ask|won't ask|not share|share na karein|kisi ko na batayein|کسی کو نہ بتائیں|किसी के साथ साझा न करें|لا تشارك)",
    caseSensitive: false,
  );

  // Real alerts send you to the official app instead of a link ("open the X app").
  static final RegExp _officialApp = RegExp(
    r"(open the .{1,30}\bapp\b|in the .{1,30}\bapp\b|inside the .{1,30}\bapp\b|official .{1,30}\bapp\b|apni app mein|app mein jaa)",
    caseSensitive: false,
  );

  // Someone asking YOU to hand over a secret: the strongest scam sign.
  static final RegExp _asksSecret = RegExp(
    r"((share|send|give|tell|reply with|forward|provide|read out|bhej|bata|batao|batayein|de dein|dedo|do)\b.{0,30}\b(otp|code|pin|password|passcode|cvv|login|card number|cnic)|\b(otp|code|pin|password|cvv)\b.{0,20}\b(bhej|bata|batao|batayein|share kar|send kar|de do|dedo|de dein))",
    caseSensitive: false,
  );

  // "New number, send money" family / friend impersonation.
  static final RegExp _familyImp = RegExp(
    r"(new number|naya number|phone (broke|broken|toota|kharab)|lost my phone).{0,90}(send|bhej|transfer|paisa|paise|money|urgent)",
    caseSensitive: false,
  );

  MessageReport analyze(String text) {
    final lower = text.toLowerCase();
    final signals = <Signal>[];
    for (final e in _groups.entries) {
      final hit = e.value.any((k) => _containsWord(lower, k));
      if (hit) signals.add(Signal(e.key, _weights[e.key]!));
    }
    final asks = _asksForSecret(text);
    if (asks) signals.add(const Signal('s_asks_secret', 30));
    if (_familyImp.hasMatch(text)) signals.add(const Signal('s_family_imp', 30));
    // A genuine notice never asks you to hand a code over.
    final safeOtp = !asks && (_safeOtpNotice.hasMatch(text) || _officialApp.hasMatch(text));
    if (safeOtp) {
      signals.removeWhere((s) => s.code == 's_otp' || s.code == 's_credentials' || s.code == 's_urgent' || s.code == 's_threat');
    }

    final links = UrlAnalyzer.extractUrls(text).map(UrlAnalyzer.analyze).toList();
    final worstLink = links.isEmpty ? 0 : links.map((l) => l.score).reduce(max);
    if (links.isNotEmpty && worstLink >= 25) signals.add(Signal('s_bad_link', worstLink ~/ 2));

    final ai = _model.predict(text);
    final known = _model.knownTokens(text);
    // Trust the model more when it recognises many words.
    final aiWeight = known >= 4 ? 1.0 : known / 4.0;
    final ruleScore = signals.fold<int>(0, (a, s) => a + s.weight);
    // When the rules already found real red flags, the model may not talk the score down by much.
    final aiFloor = ruleScore >= 30 ? -6.0 : -25.0;
    final aiScore = ((ai - 0.5) * 2 * 45 * aiWeight).clamp(aiFloor, 45.0);
    var score = (ruleScore + aiScore).round();
    if (worstLink >= 60) score = max(score, worstLink);
    if (safeOtp && worstLink < 25) score = min(score, 20);
    if (ai > 0.8 && known >= 4) signals.add(const Signal('s_ai_pattern', 0));
    return MessageReport(text, score.clamp(0, 100), ai, signals, links);
  }

  /// True when the text asks the reader to hand over a code / PIN / password.
  /// "Never share this code" (a warning) does not count: negations are skipped.
  static bool _asksForSecret(String text) {
    for (final m in _asksSecret.allMatches(text)) {
      final before = text.substring(max(0, m.start - 16), m.start).toLowerCase();
      final negated = RegExp(r"(never|not|n't|dont|nahi|nahin|mat|na)\s*$").hasMatch(before) ||
          RegExp(r"(never|do not|don't|please do not)\s+\w*\s*$").hasMatch(before);
      if (!negated) return true;
    }
    return false;
  }

  static bool _containsWord(String haystack, String needle) {
    final n = needle.toLowerCase();
    if (RegExp(r'^[a-z0-9 ]+$').hasMatch(n)) {
      return RegExp('(^|[^a-z0-9])${RegExp.escape(n)}([^a-z0-9]|\$)').hasMatch(haystack);
    }
    return haystack.contains(n);
  }
}
