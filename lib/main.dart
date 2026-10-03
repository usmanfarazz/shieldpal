import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/scam_engine.dart';
import 'l10n/l10n.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load(detectLanguage(PlatformDispatcher.instance.locale));
  runApp(ChangeNotifierProvider.value(value: state, child: const ShieldPalApp()));
  // Heavy work runs after the first frame so the app opens instantly.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(state.postStart());
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      ScamEngine.instance.learnAll(state.userExamples); // base training + what the user taught it
    });
  });
}
