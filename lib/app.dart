import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/l10n.dart';
import 'screens/lock_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';
import 'widgets/common.dart';

class ShieldPalApp extends StatefulWidget {
  const ShieldPalApp({super.key});

  @override
  State<ShieldPalApp> createState() => _ShieldPalAppState();
}

class _ShieldPalAppState extends State<ShieldPalApp> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final app = context.read<AppState>();
    if (s == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (s == AppLifecycleState.resumed) {
      app.refreshDevice();
      // Re-lock after one minute in the background.
      if (_pausedAt != null && DateTime.now().difference(_pausedAt!).inSeconds > 60) app.lockNow();
    }
  }

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: brandBlue, brightness: b, secondary: brandPink);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF4F6FF) : const Color(0xFF0E1222),
      cardTheme: CardThemeData(
        elevation: 0,
        color: b == Brightness.light ? Colors.white : const Color(0xFF181D33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    return MaterialApp(
      title: 'ShieldPal',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: kIsWeb && Uri.base.queryParameters['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.system,
      locale: lang.materialLocale,
      supportedLocales: appLanguages.map((l) => l.materialLocale).toSet().toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: lang.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: !app.onboarded
          ? const OnboardingScreen()
          : app.locked
              ? const LockScreen()
              : const MainShell(),
    );
  }
}
