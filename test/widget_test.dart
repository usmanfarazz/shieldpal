import 'package:flutter_test/flutter_test.dart';
import 'package:shieldpal/core/family_code.dart';
import 'package:shieldpal/core/password_checker.dart';
import 'package:shieldpal/core/qr_analyzer.dart';
import 'package:shieldpal/core/scam_engine.dart';
import 'package:shieldpal/core/totp.dart';
import 'package:shieldpal/core/url_analyzer.dart';

void main() {
  group('UrlAnalyzer', () {
    test('official sites are safe', () {
      for (final u in [
        'https://www.google.com',
        'https://ff.garena.com/en/',
        'https://www.jazzcash.com.pk',
        'https://www.easypaisa.com.pk/',
        'https://youtube.com/watch?v=abc',
        'https://public-library.com',
        'https://www.hbl.com',
      ]) {
        expect(UrlAnalyzer.analyze(u).verdict, Verdict.safe, reason: u);
      }
    });

    test('phishing look-alikes are dangerous', () {
      for (final u in [
        'http://ff-garena-diamonds.xyz/login',
        'https://jazzcash-verify.online/kyc',
        'easypaisa-inaam.top',
        'http://faceb00k-login.com',
        'https://roblox-free-robux.site/claim',
        'http://hbl-secure-login.com',
        'http://192.168.10.5/paypal/login',
        'https://google.com@evil.example.xyz/',
      ]) {
        expect(UrlAnalyzer.analyze(u).verdict, Verdict.dangerous, reason: u);
      }
    });

    test('extracts links from text', () {
      final urls = UrlAnalyzer.extractUrls('Bro check this ff-reward.xyz/free and https://youtube.com/x, ok?');
      expect(urls, containsAll(['ff-reward.xyz/free', 'https://youtube.com/x']));
    });
  });

  group('ScamEngine', () {
    final e = ScamEngine.instance;
    test('catches scams in several languages', () {
      for (final m in [
        'Aapka JazzCash account band ho gaya hai, foran apna PIN bhejein warna account block',
        'Galti se aapke number par code chala gaya, please woh code mujhe bhej dein',
        'Congratulations! You won a prize. Pay the delivery fee today to claim it',
        'Get free Free Fire diamonds now, login with Facebook: ff-diamonds.xyz',
        'آپ کا انعام نکلا ہے، اپنا شناختی کارڈ نمبر اور کوڈ بھیجیں',
      ]) {
        expect(e.analyze(m).score, greaterThanOrEqualTo(60), reason: m);
      }
    });

    test('normal chats stay calm', () {
      for (final m in [
        'Bro aaj raat Free Fire khelenge? 9 baje online aa jana',
        'Ammi main shaam ko ghar aunga',
        'Your OTP for login is 482910. Do not share it with anyone.',
        'Meeting moved to 3 pm tomorrow',
        'Are you free tonight for dinner?',
      ]) {
        expect(e.analyze(m).score, lessThan(30), reason: m);
      }
    });
  });

  group('TOTP', () {
    // RFC 6238 test vector: secret "12345678901234567890" (ASCII), SHA1.
    final secret = Totp.base32Encode('12345678901234567890'.codeUnits);
    test('matches RFC 6238 vectors', () {
      expect(Totp.generate(secret, DateTime.fromMillisecondsSinceEpoch(59 * 1000), digits: 8), '94287082');
      expect(Totp.generate(secret, DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000), digits: 8), '07081804');
      expect(Totp.generate(secret, DateTime.fromMillisecondsSinceEpoch(2000000000 * 1000), digits: 8), '69279037');
    });

    test('parses otpauth links', () {
      final a = TotpAccount.fromUri('otpauth://totp/Instagram:me%40mail.com?secret=JBSWY3DPEHPK3PXP&issuer=Instagram')!;
      expect(a.issuer, 'Instagram');
      expect(a.label, 'me@mail.com');
      expect(a.codeAt(DateTime.now()).length, 6);
    });
  });

  test('family circle round-trips through its QR code', () {
    final c = FamilyCircle(id: '1', name: 'Home', secret: Totp.randomSecret());
    final joined = FamilyCircle.fromQr(c.toQr())!;
    final t = DateTime.now();
    expect(joined.codeAt(t), c.codeAt(t));
    expect(c.codeAt(t).length, 3);
  });

  test('QR analyzer classifies payloads', () {
    expect(QrAnalyzer.analyze('WIFI:T:nopass;S:FreeWifi;;').kind, QrKind.wifi);
    expect(QrAnalyzer.analyze('WIFI:T:nopass;S:FreeWifi;;').risk, greaterThan(25));
    expect(QrAnalyzer.analyze('otpauth://totp/X?secret=JBSWY3DPEHPK3PXP').kind, QrKind.otpauth);
    expect(QrAnalyzer.analyze('https://pay-parking-city.top/pay').risk, greaterThanOrEqualTo(25));
  });

  test('password checker', () {
    expect(PasswordChecker.analyze('123456').strength, 0);
    expect(PasswordChecker.analyze('Tr0ub4dor&3-Horse!Mango').strength, greaterThanOrEqualTo(3));
    final g = PasswordChecker.generate();
    expect(g.length, 16);
  });
}
