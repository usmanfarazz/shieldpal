import 'package:flutter_test/flutter_test.dart';
import 'package:shieldpal/core/url_analyzer.dart';

/// How well does the offline link analyser separate fake links from real ones?
void main() {
  test('offline link analyser: fake vs real', () {
    const fake = [
      'http://ff-garena-event.xyz/login', 'https://garena-free-diamonds.top/claim', 'http://g00gle-verify.com/account',
      'https://paypa1-secure-login.com/', 'http://netflix-billing-help.club/update', 'https://jazzcash-kyc.online/verify',
      'http://easypaisa-bonus.site/claim?id=1', 'https://hbl-secure.top/login', 'http://192.168.5.7/bank/login.php',
      'https://bit.ly/3xYzAbC', 'http://tcs-delivery-pk.online/pay', 'https://facebook.com@evil-site.xyz/login',
      'https://xn--pypal-4ve.com/signin', 'http://mod-apk-download.xyz/free-fire.apk', 'https://whatsapp-gold-update.click/',
      'http://instagram-verify-badge.live/apply', 'https://binance-airdrop.live/connect-wallet', 'http://roblox-free-robux.site/',
      'https://apple-id-locked-support.com/unlock', 'http://sbi-netbanking-update.cfd/login', 'https://pubg-uc-generator.icu/',
      'https://meta-appeal-center.com/copyright', 'http://nadra-verification-pk.shop/cnic', 'https://tinyurl.com/free-iphone-win',
      'http://amazon-order-problem.work/pay', 'https://telegram-premium-free.buzz/', 'http://www.freefire-pass.top/login',
      'https://cutt.ly/AbCdEf', 'http://login-microsoft-office365.xyz/', 'https://k-electric-bill-pk.online/pay',
    ];
    const real = [
      'https://www.google.com/search?q=cats', 'https://github.com/flutter/flutter', 'https://www.youtube.com/watch?v=abc',
      'https://en.wikipedia.org/wiki/Pakistan', 'https://www.daraz.pk/products/', 'https://www.facebook.com/',
      'https://www.instagram.com/p/xyz', 'https://web.whatsapp.com/', 'https://www.garena.com/', 'https://store.steampowered.com/',
      'https://www.paypal.com/signin', 'https://www.hbl.com/', 'https://easypaisa.com.pk/', 'https://www.amazon.com/dp/B000',
      'https://maps.google.com/?q=lahore', 'https://docs.google.com/document/d/1', 'https://www.dawn.com/news/123',
      'https://www.netflix.com/browse', 'https://www.apple.com/iphone/', 'https://www.microsoft.com/en-us/',
      'https://www.bbc.com/news', 'https://www.nytimes.com/', 'https://stackoverflow.com/questions/1', 'https://www.olx.com.pk/',
      'https://www.tcs.com.pk/', 'https://www.binance.com/en', 'https://discord.com/channels/@me', 'https://t.me/durov',
      'https://www.linkedin.com/in/x', 'https://www.nadra.gov.pk/',
    ];
    var caught = 0, passed = 0;
    final missed = <String>[], alarm = <String>[];
    for (final u in fake) {
      final s = UrlAnalyzer.analyze(u).score;
      if (s >= 25) {
        caught++;
      } else {
        missed.add('[$s] $u');
      }
    }
    for (final u in real) {
      final s = UrlAnalyzer.analyze(u).score;
      if (s < 25) {
        passed++;
      } else {
        alarm.add('[$s] $u');
      }
    }
    // ignore: avoid_print
    print('fake caught: $caught/${fake.length}   real passed: $passed/${real.length}');
    for (final m in missed) {
      // ignore: avoid_print
      print('MISSED  $m');
    }
    for (final m in alarm) {
      // ignore: avoid_print
      print('FALSE+  $m');
    }
    // Short links (bit.ly...) hide their target: Link Check expands them online and judges the real destination.
    expect(caught / fake.length, greaterThanOrEqualTo(0.9));
    expect(passed / real.length, greaterThan(0.95));
  });
}
