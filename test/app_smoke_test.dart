import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldpal/app.dart';
import 'package:shieldpal/l10n/l10n.dart';
import 'package:shieldpal/screens/assistant_screen.dart';
import 'package:shieldpal/screens/family_screen.dart';
import 'package:shieldpal/screens/link_check_screen.dart';
import 'package:shieldpal/screens/message_check_screen.dart';
import 'package:shieldpal/screens/number_check_screen.dart';
import 'package:shieldpal/screens/password_screen.dart';
import 'package:shieldpal/screens/protection_screen.dart';
import 'package:shieldpal/screens/quiz_screen.dart';
import 'package:shieldpal/screens/scan_screen.dart';
import 'package:shieldpal/screens/threats_screen.dart';
import 'package:shieldpal/state/app_state.dart';

Future<AppState> _boot(WidgetTester tester, {bool onboarded = true, String lang = 'en'}) async {
  SharedPreferences.setMockInitialValues({
    if (onboarded) 'state_v1': '{"onboarded":true,"lang":"$lang","petName":"Pip"}',
  });
  final app = AppState();
  await tester.runAsync(() => app.load(lang));
  await tester.pumpWidget(ChangeNotifierProvider.value(value: app, child: const ShieldPalApp()));
  await tester.pump(const Duration(milliseconds: 500));
  return app;
}

Future<void> _open(WidgetTester tester, Widget screen) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.push(MaterialPageRoute(builder: (_) => screen));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull, reason: screen.runtimeType.toString());
  nav.pop();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    final w = TestWidgetsFlutterBinding.ensureInitialized();
    w.platformDispatcher.views.first.physicalSize = const Size(1080, 2340);
    w.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  testWidgets('onboarding shows', (tester) async {
    await _boot(tester, onboarded: false);
    expect(find.text('ShieldPal'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final lang in appLanguages.map((l) => l.code)) {
    testWidgets('all screens render ($lang)', (tester) async {
      await _boot(tester, lang: lang);
      expect(find.text(tr('scan_phone')), findsOneWidget);
      // Bottom tabs.
      for (final key in ['tab_tools', 'tab_play', 'tab_vault', 'tab_settings', 'tab_home']) {
        await tester.tap(find.text(tr(key)).last);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: key);
      }
      for (final s in const [
        LinkCheckScreen(),
        MessageCheckScreen(initial: 'Aapka JazzCash account band ho gaya hai, foran PIN bhejein jazzcash-kyc.online'),
        NumberCheckScreen(),
        PasswordScreen(),
        ProtectionScreen(),
        FamilyScreen(),
        ThreatsScreen(),
        AssistantScreen(),
        QuizScreen(),
      ]) {
        await _open(tester, s);
      }
      // Let the pet's 20-second "alarmed" timer run out.
      await tester.pump(const Duration(seconds: 30));
    });
  }

  testWidgets('deep scan fallback works', (tester) async {
    // Pretend to be an iPhone: the limited (non-Android) check-up is used.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _boot(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => const ScanScreen()));
    await tester.pump(); // builds the screen and starts the scan
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(tr('checkup')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 30));
    debugDefaultTargetPlatformOverride = null;
  });
}
