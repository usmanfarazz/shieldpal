import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/device_bridge.dart';
import '../core/family_code.dart';
import '../core/scam_engine.dart';
import '../core/secure_store.dart';
import '../core/totp.dart';
import '../l10n/l10n.dart';
import '../widgets/pet_view.dart';

class ShopItem {
  final String id;
  final String slot; // hat | glasses | extra | skin
  final String value;
  final int price;
  final String emoji;
  const ShopItem(this.id, this.slot, this.value, this.price, this.emoji);
}

const List<ShopItem> shopItems = [
  ShopItem('hat_cap', 'hat', 'cap', 40, '🧢'),
  ShopItem('hat_party', 'hat', 'party', 40, '🥳'),
  ShopItem('hat_chef', 'hat', 'chef', 60, '👨‍🍳'),
  ShopItem('hat_headphones', 'hat', 'headphones', 80, '🎧'),
  ShopItem('hat_wizard', 'hat', 'wizard', 120, '🧙'),
  ShopItem('hat_crown', 'hat', 'crown', 200, '👑'),
  ShopItem('gl_nerd', 'glasses', 'nerd', 50, '🤓'),
  ShopItem('gl_star', 'glasses', 'star', 70, '🤩'),
  ShopItem('gl_shades', 'glasses', 'shades', 90, '😎'),
  ShopItem('ex_bowtie', 'extra', 'bowtie', 40, '🎀'),
  ShopItem('ex_scarf', 'extra', 'scarf', 60, '🧣'),
  ShopItem('ex_medal', 'extra', 'medal', 100, '🏅'),
  ShopItem('ex_cape', 'extra', 'cape', 150, '🦸'),
  ShopItem('skin_1', 'skin', '1', 80, '🌅'),
  ShopItem('skin_2', 'skin', '2', 80, '🍇'),
  ShopItem('skin_3', 'skin', '3', 80, '🌿'),
  ShopItem('skin_4', 'skin', '4', 100, '🍯'),
  ShopItem('skin_5', 'skin', '5', 100, '🍬'),
  ShopItem('skin_6', 'skin', '6', 150, '🥷'),
  ShopItem('skin_7', 'skin', '7', 150, '❄️'),
];

class Achievement {
  final String id;
  final String emoji;
  final int reward;
  const Achievement(this.id, this.emoji, this.reward);
}

const List<Achievement> achievements = [
  Achievement('a_first_scan', '🔍', 20),
  Achievement('a_link_detective', '🕵️', 30),
  Achievement('a_scam_buster', '🛡️', 50),
  Achievement('a_quiz_master', '🧠', 50),
  Achievement('a_streak_7', '🔥', 70),
  Achievement('a_fort_knox', '🏰', 100),
  Achievement('a_two_factor', '🔐', 40),
  Achievement('a_family', '👨‍👩‍👧', 40),
  Achievement('a_guardian', '🦾', 60),
  Achievement('a_qr', '📷', 20),
];

class AppState extends ChangeNotifier {
  late SharedPreferences _prefs;
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<Threat>? _threatSub;

  // ---- persisted ----
  String lang = 'en';
  bool onboarded = false;
  String petName = 'Pip';
  int coins = 50;
  int xp = 0;
  int streak = 0;
  String lastCheckIn = '';
  Set<String> owned = {};
  Set<String> unlocked = {};
  String hat = 'none', glasses = 'none', extra = 'none';
  int skin = 0;
  bool voiceAlerts = true;
  bool alarmSound = true;
  bool appLock = false;
  bool biometric = true;
  String homeCountry = 'PK';
  Set<String> reportedNumbers = {};
  int linksChecked = 0, scamsCaught = 0, quizCorrect = 0, quizBest = 0;
  List<Threat> threats = [];
  DeviceAudit? lastAudit;
  DateTime? lastAuditTime;
  bool assistantOnline = false;
  String species = 'cat';
  String voiceName = '';
  String voiceLocale = '';
  double voicePitch = 1.25;
  double voiceRate = 0.48;
  int freeAi = 0; // 0 = not asked yet, 1 = on, 2 = off
  String vpnDns = 'cf_security';
  bool cloudCheck = true; // keyless Cloudflare reputation check for links
  List<(String, int)> userExamples = []; // messages the user taught the scam model
  String tipReadDate = ''; // day the user last opened the tip of the day
  bool _started = false;

  // ---- secrets (secure storage) ----
  List<TotpAccount> totp = [];
  List<FamilyCircle> circles = [];

  // ---- runtime ----
  bool liveGuard = false;
  bool vpnOn = false;
  bool wgOn = false;
  int vpnBlocked = 0;
  DateTime? _alarmUntil;
  bool locked = false;
  String? pendingShared;

  AppLanguage get language => languageFor(lang);
  PetLook get look => PetLook(skin: skin, hat: hat, glasses: glasses, extra: extra, species: species);

  Future<void> load(String systemLang) async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('state_v1');
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    } else {
      lang = systemLang;
    }
    // Web demo (landing page): ?demo=1 opens the app directly, without the first-run screens.
    if (kIsWeb && Uri.base.queryParameters['demo'] == '1' && !onboarded) {
      onboarded = true;
      petName = 'Pip';
    }
    L10n.current = language;
    locked = appLock;
  }

  /// Slower start-up work (encrypted storage, native calls). Runs after the
  /// first frame so the app opens instantly.
  Future<void> postStart() async {
    if (_started) return;
    _started = true;
    try {
      final t = await SecureStore.instance.read(SecureStore.totpAccounts);
      if (t != null) {
        totp = (jsonDecode(t) as List).map((e) => TotpAccount.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      final c = await SecureStore.instance.read(SecureStore.familyCircles);
      if (c != null) {
        circles = (jsonDecode(c) as List).map((e) => FamilyCircle.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    await refreshDevice();
    _threatSub = DeviceBridge.instance.liveThreats.listen((t) => addThreat(t, fromNative: true));
    DeviceBridge.instance.sharedText.listen((s) {
      pendingShared = s;
      notifyListeners();
    });
    pendingShared = await DeviceBridge.instance.initialLink();
    await pushNativeConfig();
    notifyListeners();
  }

  @override
  void dispose() {
    _threatSub?.cancel();
    super.dispose();
  }

  void _fromJson(Map<String, dynamic> j) {
    lang = j['lang'] as String? ?? lang;
    onboarded = j['onboarded'] == true;
    petName = j['petName'] as String? ?? petName;
    coins = j['coins'] as int? ?? coins;
    xp = j['xp'] as int? ?? 0;
    streak = j['streak'] as int? ?? 0;
    lastCheckIn = j['lastCheckIn'] as String? ?? '';
    owned = ((j['owned'] as List?) ?? const []).map((e) => '$e').toSet();
    unlocked = ((j['unlocked'] as List?) ?? const []).map((e) => '$e').toSet();
    hat = j['hat'] as String? ?? 'none';
    glasses = j['glasses'] as String? ?? 'none';
    extra = j['extra'] as String? ?? 'none';
    skin = j['skin'] as int? ?? 0;
    voiceAlerts = j['voiceAlerts'] as bool? ?? true;
    alarmSound = j['alarmSound'] as bool? ?? true;
    appLock = j['appLock'] as bool? ?? false;
    biometric = j['biometric'] as bool? ?? true;
    homeCountry = j['homeCountry'] as String? ?? 'PK';
    reportedNumbers = ((j['reported'] as List?) ?? const []).map((e) => '$e').toSet();
    linksChecked = j['linksChecked'] as int? ?? 0;
    scamsCaught = j['scamsCaught'] as int? ?? 0;
    quizCorrect = j['quizCorrect'] as int? ?? 0;
    quizBest = j['quizBest'] as int? ?? 0;
    assistantOnline = j['assistantOnline'] as bool? ?? false;
    species = j['species'] as String? ?? 'cat';
    voiceName = j['voiceName'] as String? ?? '';
    voiceLocale = j['voiceLocale'] as String? ?? '';
    voicePitch = (j['voicePitch'] as num?)?.toDouble() ?? 1.25;
    voiceRate = (j['voiceRate'] as num?)?.toDouble() ?? 0.48;
    freeAi = j['freeAi'] as int? ?? 0;
    vpnDns = j['vpnDns'] as String? ?? 'cf_security';
    cloudCheck = j['cloudCheck'] as bool? ?? true;
    tipReadDate = j['tipReadDate'] as String? ?? '';
    userExamples = ((j['examples'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ((e['t'] ?? '').toString(), (e['l'] as num?)?.toInt() ?? 0))
        .toList();
    threats = ((j['threats'] as List?) ?? const [])
        .map((e) => Threat.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final a = j['auditTime'] as int?;
    lastAuditTime = a == null ? null : DateTime.fromMillisecondsSinceEpoch(a);
    final audit = j['audit'];
    if (audit is Map) lastAudit = DeviceAudit.fromJson(Map<String, dynamic>.from(audit));
  }

  Map<String, dynamic> _auditJson(DeviceAudit a) => {
        'checks': a.checks.map((c) => {'id': c.id, 'status': c.status, 'detail': c.detail, 'fix': c.fix}).toList(),
        'apps': a.riskyApps
            .map((r) => {
                  'package': r.package,
                  'label': r.label,
                  'score': r.score,
                  'reasons': r.reasons,
                  'sideloaded': r.sideloaded,
                  'admin': r.isAdmin,
                })
            .toList(),
        'scanned': a.appsScanned,
        'harmful': a.harmfulByGoogle,
      };

  Future<void> save() async {
    final j = {
      'lang': lang,
      'onboarded': onboarded,
      'petName': petName,
      'coins': coins,
      'xp': xp,
      'streak': streak,
      'lastCheckIn': lastCheckIn,
      'owned': owned.toList(),
      'unlocked': unlocked.toList(),
      'hat': hat,
      'glasses': glasses,
      'extra': extra,
      'skin': skin,
      'voiceAlerts': voiceAlerts,
      'alarmSound': alarmSound,
      'appLock': appLock,
      'biometric': biometric,
      'homeCountry': homeCountry,
      'reported': reportedNumbers.toList(),
      'linksChecked': linksChecked,
      'scamsCaught': scamsCaught,
      'quizCorrect': quizCorrect,
      'quizBest': quizBest,
      'assistantOnline': assistantOnline,
      'species': species,
      'voiceName': voiceName,
      'voiceLocale': voiceLocale,
      'voicePitch': voicePitch,
      'voiceRate': voiceRate,
      'freeAi': freeAi,
      'vpnDns': vpnDns,
      'cloudCheck': cloudCheck,
      'tipReadDate': tipReadDate,
      'examples': userExamples.map((e) => {'t': e.$1, 'l': e.$2}).toList(),
      'threats': threats.take(200).map((t) => t.toJson()).toList(),
      'auditTime': lastAuditTime?.millisecondsSinceEpoch,
      'audit': lastAudit == null ? null : _auditJson(lastAudit!),
    };
    await _prefs.setString('state_v1', jsonEncode(j));
  }

  void _changed() {
    notifyListeners();
    save();
  }

  // ---------------- language ----------------
  Future<void> setLanguage(String code) async {
    lang = code;
    L10n.current = language;
    // A voice picked for the old language would read the new one badly.
    voiceName = '';
    voiceLocale = '';
    _changed();
    await pushNativeConfig();
  }

  /// The background service cannot read Dart code, so it gets the already
  /// translated alert texts plus the user's settings.
  Future<void> pushNativeConfig() async {
    await DeviceBridge.instance.pushConfig({
      'voice': voiceAlerts,
      'alarm': alarmSound,
      'tts': voiceLocale.isNotEmpty ? voiceLocale : language.ttsLocale,
      'ttsVoice': voiceName,
      'ttsPitch': voicePitch,
      'ttsRate': voiceRate,
      'vpnDns': vpnDns,
      'cloudCheck': cloudCheck,
      'petName': petName,
      'safeBrowsingKey': await SecureStore.instance.read(SecureStore.safeBrowsingKey) ?? '',
      'txt_link_title': tr('n_link_title'),
      'txt_link_body': tr('n_link_body'),
      'txt_msg_title': tr('n_msg_title'),
      'txt_msg_body': tr('n_msg_body'),
      'txt_app_title': tr('n_app_title'),
      'txt_app_body': tr('n_app_body'),
      'txt_speak_link': tr('speak_link'),
      'txt_speak_msg': tr('speak_msg'),
      'txt_speak_app': tr('speak_app'),
      'txt_channel': tr('n_channel'),
      'txt_vpn_running': tr('vpn_running'),
    });
  }

  // ---------------- device / protection ----------------
  Future<void> refreshDevice() async {
    liveGuard = await DeviceBridge.instance.isLiveGuardEnabled();
    vpnOn = await DeviceBridge.instance.isVpnRunning();
    wgOn = await DeviceBridge.instance.wgIsUp();
    vpnBlocked = await DeviceBridge.instance.vpnBlockedCount();
    final native = await DeviceBridge.instance.fetchThreats();
    for (final t in native) {
      if (!threats.any((x) => x.id == t.id)) threats.insert(0, t);
    }
    if (native.isNotEmpty) {
      await DeviceBridge.instance.clearNativeThreats();
      scamsCaught += native.length;
      _checkAchievements();
      save();
    }
    if (liveGuard && vpnOn) unlock('a_guardian');
    notifyListeners();
  }

  void setAudit(DeviceAudit a) {
    lastAudit = a;
    lastAuditTime = DateTime.now();
    unlock('a_first_scan');
    if (a.score >= 100) unlock('a_fort_knox');
    _changed();
  }

  // ---------------- pet ----------------
  List<Threat> get activeThreats => threats
      .where((t) => !t.resolved && DateTime.now().difference(t.time).inHours < 48 && t.score >= 60)
      .toList();

  int get health {
    var h = (lastAudit?.score ?? 75).toDouble();
    h -= activeThreats.length * 12;
    if (liveGuard) h += 5;
    if (vpnOn) h += 4;
    if (appLock) h += 3;
    if (totp.isNotEmpty) h += 3;
    h += streak.clamp(0, 5);
    return h.round().clamp(0, 100);
  }

  PetMood get mood {
    if (_alarmUntil != null && DateTime.now().isBefore(_alarmUntil!)) return PetMood.alarmed;
    final h = health;
    if (h >= 80) return PetMood.happy;
    if (h >= 55) return PetMood.ok;
    if (h >= 30) return PetMood.worried;
    return PetMood.sick;
  }

  int get level => 1 + xp ~/ 100;

  void alarm() {
    _alarmUntil = DateTime.now().add(const Duration(seconds: 20));
    notifyListeners();
    Future<void>.delayed(const Duration(seconds: 21), notifyListeners);
  }

  // ---------------- threats ----------------
  Future<void> addThreat(Threat t, {bool fromNative = false, bool speak = false}) async {
    if (threats.any((x) => x.id == t.id)) return;
    threats.insert(0, t);
    if (t.score >= 60) {
      scamsCaught++;
      alarm();
      if (speak && voiceAlerts) await say(tr(t.kind == 'link' ? 'speak_link' : 'speak_msg', {'pet': petName}));
    }
    if (fromNative) await DeviceBridge.instance.clearNativeThreats();
    _checkAchievements();
    _changed();
  }

  void resolveThreat(Threat t) {
    t.resolved = true;
    addCoins(5);
    _changed();
  }

  void clearThreats() {
    threats.clear();
    _changed();
  }

  Future<void> say(String text) async {
    try {
      await _tts.setLanguage(voiceLocale.isNotEmpty ? voiceLocale : language.ttsLocale);
      if (voiceName.isNotEmpty) {
        await _tts.setVoice({'name': voiceName, 'locale': voiceLocale});
      }
      await _tts.setSpeechRate(voiceRate);
      await _tts.setPitch(voicePitch);
      await _tts.speak(text);
    } catch (_) {}
  }

  // ---------------- game economy ----------------
  void addCoins(int n, {int xpGain = 0}) {
    coins += n;
    xp += xpGain == 0 ? n : xpGain;
    _changed();
  }

  bool unlock(String id) {
    if (unlocked.contains(id)) return false;
    final a = achievements.firstWhere((x) => x.id == id, orElse: () => const Achievement('', '', 0));
    if (a.id.isEmpty) return false;
    unlocked.add(id);
    coins += a.reward;
    xp += a.reward;
    lastUnlocked = id;
    _changed();
    return true;
  }

  String? lastUnlocked;

  void _checkAchievements() {
    if (linksChecked >= 10) unlock('a_link_detective');
    if (scamsCaught >= 5) unlock('a_scam_buster');
    if (quizCorrect >= 30) unlock('a_quiz_master');
    if (streak >= 7) unlock('a_streak_7');
    if (totp.isNotEmpty) unlock('a_two_factor');
    if (circles.isNotEmpty) unlock('a_family');
  }

  /// Returns coins earned (0 when already checked in today).
  int dailyCheckIn() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastCheckIn == today) return 0;
    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    streak = lastCheckIn == yesterday ? streak + 1 : 1;
    lastCheckIn = today;
    final reward = 10 + (streak.clamp(1, 7) * 2);
    coins += reward;
    xp += reward;
    _checkAchievements();
    _changed();
    return reward;
  }

  bool get tipReadToday => tipReadDate == DateTime.now().toIso8601String().substring(0, 10);

  /// +2 coins the first time the user opens the tip of the day each day.
  int readTipToday() {
    if (tipReadToday) return 0;
    tipReadDate = DateTime.now().toIso8601String().substring(0, 10);
    addCoins(2);
    return 2;
  }

  bool get checkedInToday => lastCheckIn == DateTime.now().toIso8601String().substring(0, 10);

  bool buy(ShopItem item) {
    if (owned.contains(item.id)) return true;
    if (coins < item.price) return false;
    coins -= item.price;
    owned.add(item.id);
    equip(item);
    return true;
  }

  void equip(ShopItem item) {
    switch (item.slot) {
      case 'hat':
        hat = hat == item.value ? 'none' : item.value;
      case 'glasses':
        glasses = glasses == item.value ? 'none' : item.value;
      case 'extra':
        extra = extra == item.value ? 'none' : item.value;
      case 'skin':
        skin = skin == int.parse(item.value) ? 0 : int.parse(item.value);
    }
    _changed();
  }

  bool isEquipped(ShopItem item) => switch (item.slot) {
        'hat' => hat == item.value,
        'glasses' => glasses == item.value,
        'extra' => extra == item.value,
        _ => skin.toString() == item.value,
      };

  // Dangerous results are counted in scamsCaught by addThreat().
  void recordLinkCheck(int score) {
    linksChecked++;
    addCoins(2);
    _checkAchievements();
  }

  void recordQuiz(int correct, int total) {
    quizCorrect += correct;
    if (correct > quizBest) quizBest = correct;
    addCoins(correct * 3);
    _checkAchievements();
  }

  // ---------------- settings ----------------
  void update(void Function(AppState s) f) {
    f(this);
    _changed();
    pushNativeConfig();
  }

  void finishOnboarding(String name) {
    petName = name.trim().isEmpty ? 'Pip' : name.trim();
    onboarded = true;
    _changed();
    pushNativeConfig();
  }

  /// Erases everything ShieldPal stores on this phone.
  Future<void> deleteAllData() async {
    await _prefs.clear();
    await SecureStore.instance.deleteAll();
    await DeviceBridge.instance.clearNativeThreats();
    await DeviceBridge.instance.wipeNative();
    totp = [];
    circles = [];
    threats = [];
    lastAudit = null;
    lastAuditTime = null;
    owned = {};
    unlocked = {};
    reportedNumbers = {};
    userExamples = [];
    coins = 50;
    xp = 0;
    streak = 0;
    lastCheckIn = '';
    hat = glasses = extra = 'none';
    skin = 0;
    species = 'cat';
    petName = 'Pip';
    appLock = false;
    locked = false;
    assistantOnline = false;
    freeAi = 0;
    voiceName = '';
    voiceLocale = '';
    onboarded = false;
    linksChecked = scamsCaught = quizCorrect = quizBest = 0;
    notifyListeners();
  }

  /// (current, target) for the achievement progress bars.
  (int, int) achievementProgress(String id) => switch (id) {
        'a_first_scan' => (lastAudit == null ? 0 : 1, 1),
        'a_link_detective' => (linksChecked.clamp(0, 10), 10),
        'a_scam_buster' => (scamsCaught.clamp(0, 5), 5),
        'a_quiz_master' => (quizCorrect.clamp(0, 30), 30),
        'a_streak_7' => (streak.clamp(0, 7), 7),
        'a_fort_knox' => ((lastAudit?.score ?? 0).clamp(0, 100), 100),
        'a_two_factor' => (totp.isEmpty ? 0 : 1, 1),
        'a_family' => (circles.isEmpty ? 0 : 1, 1),
        'a_guardian' => ((liveGuard ? 1 : 0) + (vpnOn ? 1 : 0), 2),
        _ => (unlocked.contains(id) ? 1 : 0, 1),
      };

  void unlockApp() {
    locked = false;
    notifyListeners();
  }

  void lockNow() {
    if (appLock) {
      locked = true;
      notifyListeners();
    }
  }

  // ---------------- secrets ----------------
  Future<void> _saveTotp() async =>
      SecureStore.instance.write(SecureStore.totpAccounts, jsonEncode(totp.map((e) => e.toJson()).toList()));
  Future<void> _saveCircles() async =>
      SecureStore.instance.write(SecureStore.familyCircles, jsonEncode(circles.map((e) => e.toJson()).toList()));

  Future<void> addTotp(TotpAccount a) async {
    totp.add(a);
    await _saveTotp();
    _checkAchievements();
    notifyListeners();
  }

  Future<void> removeTotp(TotpAccount a) async {
    totp.removeWhere((x) => x.id == a.id);
    await _saveTotp();
    notifyListeners();
  }

  Future<void> addCircle(FamilyCircle c) async {
    circles.add(c);
    await _saveCircles();
    _checkAchievements();
    notifyListeners();
  }

  Future<void> removeCircle(FamilyCircle c) async {
    circles.removeWhere((x) => x.id == c.id);
    await _saveCircles();
    notifyListeners();
  }

  void unreportNumber(String international) {
    reportedNumbers.remove(international);
    _changed();
  }

  /// "This is a scam / this is safe": the on-device model learns from it right away.
  void teachMessage(String text, bool isScam) {
    final t = text.length > 400 ? text.substring(0, 400) : text;
    userExamples.removeWhere((e) => e.$1 == t);
    userExamples.add((t, isScam ? 1 : 0));
    if (userExamples.length > 300) userExamples.removeAt(0);
    ScamEngine.instance.learn(t, isScam ? 1 : 0);
    addCoins(1);
  }

  void reportNumber(String international) {
    reportedNumbers.add(international);
    _changed();
  }
}
