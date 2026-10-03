import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// One line of the phone security check-up.
class AuditCheck {
  final String id; // localisation key suffix, e.g. "screen_lock"
  final String status; // ok | warn | bad | unknown
  final String detail;
  final String? fix; // native action name

  AuditCheck(this.id, this.status, this.detail, this.fix);
  factory AuditCheck.fromJson(Map<String, dynamic> j) => AuditCheck(
        j['id'] as String,
        j['status'] as String? ?? 'unknown',
        j['detail']?.toString() ?? '',
        j['fix'] as String?,
      );
}

/// An installed app that looks dangerous.
class AppRisk {
  final String package;
  final String label;
  final int score;
  final List<String> reasons; // localisation keys
  final bool sideloaded;
  final bool isAdmin;

  AppRisk(this.package, this.label, this.score, this.reasons, this.sideloaded, this.isAdmin);
  factory AppRisk.fromJson(Map<String, dynamic> j) => AppRisk(
        j['package'] as String,
        j['label'] as String? ?? j['package'] as String,
        j['score'] as int? ?? 0,
        ((j['reasons'] as List?) ?? const []).map((e) => e.toString()).toList(),
        j['sideloaded'] == true,
        j['admin'] == true,
      );
}

class DeviceAudit {
  final List<AuditCheck> checks;
  final List<AppRisk> riskyApps;
  final int appsScanned;
  final List<String> harmfulByGoogle;
  DeviceAudit(this.checks, this.riskyApps, this.appsScanned, this.harmfulByGoogle);

  factory DeviceAudit.fromJson(Map<String, dynamic> j) => DeviceAudit(
        ((j['checks'] as List?) ?? const []).map((e) => AuditCheck.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        ((j['apps'] as List?) ?? const []).map((e) => AppRisk.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        j['scanned'] as int? ?? 0,
        ((j['harmful'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );

  /// 0..100 phone health, used by the pet.
  int get score {
    var s = 100;
    for (final c in checks) {
      if (c.status == 'bad') s -= 15;
      if (c.status == 'warn') s -= 6;
    }
    for (final a in riskyApps) {
      s -= a.score >= 70 ? 20 : a.score >= 40 ? 8 : 3;
    }
    s -= harmfulByGoogle.length * 30;
    return s.clamp(0, 100);
  }
}

/// A threat caught in the background (WhatsApp / SMS link, new app, DNS block).
class Threat {
  final String id;
  final DateTime time;
  final String kind; // link | message | app | dns | qr
  final String sourceApp; // e.g. WhatsApp
  final String chat; // chat / sender name
  final String text;
  final String url;
  final int score;
  bool resolved;

  Threat({
    required this.id,
    required this.time,
    required this.kind,
    this.sourceApp = '',
    this.chat = '',
    this.text = '',
    this.url = '',
    this.score = 0,
    this.resolved = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.millisecondsSinceEpoch,
        'kind': kind,
        'app': sourceApp,
        'chat': chat,
        'text': text,
        'url': url,
        'score': score,
        'resolved': resolved,
      };

  factory Threat.fromJson(Map<String, dynamic> j) => Threat(
        id: j['id'].toString(),
        time: DateTime.fromMillisecondsSinceEpoch((j['time'] as num).toInt()),
        kind: j['kind'] as String? ?? 'message',
        sourceApp: j['app'] as String? ?? '',
        chat: j['chat'] as String? ?? '',
        text: j['text'] as String? ?? '',
        url: j['url'] as String? ?? '',
        score: (j['score'] as num?)?.toInt() ?? 0,
        resolved: j['resolved'] == true,
      );
}

/// Talks to the native Android side (Kotlin). On other platforms every call
/// returns a safe "not available" answer so the app still works.
class DeviceBridge {
  DeviceBridge._() {
    if (isAndroid) {
      _ch.setMethodCallHandler((call) async {
        if (call.method == 'onThreat') {
          final t = Threat.fromJson(Map<String, dynamic>.from(jsonDecode(call.arguments as String) as Map));
          _threats.add(t);
        } else if (call.method == 'onSharedText') {
          _shared.add(call.arguments as String);
        }
        return null;
      });
    }
  }
  static final DeviceBridge instance = DeviceBridge._();
  static const MethodChannel _ch = MethodChannel('shieldpal/device');
  final _threats = StreamController<Threat>.broadcast();
  final _shared = StreamController<String>.broadcast();

  Stream<Threat> get liveThreats => _threats.stream;
  Stream<String> get sharedText => _shared.stream;

  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _call<T>(String method, [Object? args]) async {
    if (!isAndroid) return null;
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      debugPrint('DeviceBridge.$method failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<DeviceAudit?> runAudit() async {
    final s = await _call<String>('runAudit');
    if (s == null) return null;
    return DeviceAudit.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
  }

  Future<List<Threat>> fetchThreats() async {
    final s = await _call<String>('getThreats');
    if (s == null) return [];
    return (jsonDecode(s) as List).map((e) => Threat.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> clearNativeThreats() => _call('clearThreats');
  Future<bool> isLiveGuardEnabled() async => await _call<bool>('isNotificationAccessGranted') ?? false;
  Future<void> openLiveGuardSettings() => _call('openNotificationAccess');
  Future<void> uninstall(String pkg) => _call('uninstall', pkg);
  Future<void> openAppDetails(String pkg) => _call('openAppDetails', pkg);
  Future<void> runFix(String action) => _call('fix', action);
  Future<String?> initialLink() => _call<String>('getInitialShared');

  /// Opens a link in a real browser. On Android ShieldPal may itself be the
  /// default "browser" (Safe Link Gate), so the native side picks another one.
  Future<void> openInBrowser(Uri uri) async {
    if (isAndroid) {
      final ok = await _call<bool>('openInBrowser', uri.toString());
      if (ok == true) return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens a link in the app that owns it (YouTube, Instagram...) or a browser.
  Future<void> openLink(Uri uri) async {
    if (isAndroid) {
      final ok = await _call<bool>('openLink', uri.toString());
      if (ok == true) return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> wipeNative() => _call('wipeNative');

  Future<bool> contactsAllowed() async => await _call<bool>('contactsAllowed') ?? false;
  Future<bool> requestContacts() async => await _call<bool>('requestContacts') ?? false;
  Future<String?> contactName(String number) => _call<String>('lookupContact', number);

  /// Remote VPN (user's own WireGuard config). Returns null on success, else an error text.
  Future<String?> wgStart(String config) async => await _call<String>('wgStart', config);
  Future<void> wgStop() => _call('wgStop');
  Future<bool> wgIsUp() async => await _call<bool>('wgIsUp') ?? false;

  Future<bool> startVpn() async => await _call<bool>('startVpn') ?? false;
  Future<void> stopVpn() => _call('stopVpn');
  Future<bool> isVpnRunning() async => await _call<bool>('isVpnRunning') ?? false;
  Future<int> vpnBlockedCount() async => await _call<int>('vpnBlockedCount') ?? 0;

  Future<bool> notificationsAllowed() async => await _call<bool>('notificationsAllowed') ?? true;
  Future<void> requestNotifications() => _call('requestNotifications');

  /// Pushes settings and translated alert texts to the background service,
  /// which runs even when the app is closed.
  Future<void> pushConfig(Map<String, dynamic> cfg) => _call('setConfig', jsonEncode(cfg));
}
