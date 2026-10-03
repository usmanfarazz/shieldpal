import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for secrets: API keys, 2FA seeds, app-lock PIN.
/// Uses Android Keystore / iOS Keychain / Windows DPAPI / libsecret.
class SecureStore {
  SecureStore._();
  static final SecureStore instance = SecureStore._();
  final FlutterSecureStorage _s = const FlutterSecureStorage();
  final Map<String, String?> _cache = {};

  Future<String?> read(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final v = await _s.read(key: key);
      _cache[key] = v;
      return v;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String? value) async {
    _cache[key] = value;
    try {
      if (value == null || value.isEmpty) {
        await _s.delete(key: key);
      } else {
        await _s.write(key: key, value: value);
      }
    } catch (_) {}
  }

  /// Wipes every secret (API keys, 2FA seeds, PIN, family circles).
  Future<void> deleteAll() async {
    _cache.clear();
    try {
      await _s.deleteAll();
    } catch (_) {}
  }

  static const wgConfig = 'wireguard_config';
  static const claudeKey = 'claude_api_key';
  static const safeBrowsingKey = 'safe_browsing_key';
  static const urlscanKey = 'urlscan_key';
  static const appPin = 'app_pin_hash';
  static const totpAccounts = 'totp_accounts';
  static const familyCircles = 'family_circles';
}
