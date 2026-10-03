import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../core/secure_store.dart';
import '../core/totp.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pet_view.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _wrong = false;
  int _fails = 0;
  DateTime? _blockedUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  Future<void> _bio() async {
    final app = context.read<AppState>();
    if (!app.biometric) return;
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return;
      final ok = await auth.authenticate(localizedReason: tr('unlock_reason'));
      if (ok && mounted) app.unlockApp();
    } catch (_) {}
  }

  Future<void> _press(String d) async {
    if (_blockedUntil != null && DateTime.now().isBefore(_blockedUntil!)) return;
    setState(() {
      _wrong = false;
      _pin += d;
    });
    final stored = await SecureStore.instance.read(SecureStore.appPin);
    if (stored == null) {
      if (mounted) context.read<AppState>().unlockApp();
      return;
    }
    if (_pin.length >= 4 && Totp.hashPin(_pin) == stored) {
      if (mounted) context.read<AppState>().unlockApp();
    } else if (_pin.length >= 8) {
      _fails++;
      setState(() {
        _wrong = true;
        _pin = '';
        // Slow down guessing after repeated failures.
        if (_fails >= 5) _blockedUntil = DateTime.now().add(Duration(seconds: 30 * (_fails - 4)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              PetView(mood: _wrong ? PetMood.worried : PetMood.ok, look: app.look, size: 150),
              Text(tr('locked_title'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 8; i++)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? brandBlue : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
              ]),
              if (_wrong) Text(tr('wrong_pin'), style: const TextStyle(color: dangerRed)),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 1.6,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'bio', '0', 'del'])
                    TextButton(
                      onPressed: () {
                        if (k == 'del') {
                          setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1));
                        } else if (k == 'bio') {
                          _bio();
                        } else {
                          _press(k);
                        }
                      },
                      child: k == 'del'
                          ? const Icon(Icons.backspace_rounded)
                          : k == 'bio'
                              ? const Icon(Icons.fingerprint_rounded, size: 30)
                              : Text(k, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  final stored = await SecureStore.instance.read(SecureStore.appPin);
                  if (stored != null && Totp.hashPin(_pin) == stored && context.mounted) {
                    context.read<AppState>().unlockApp();
                  } else {
                    setState(() {
                      _wrong = true;
                      _pin = '';
                    });
                  }
                },
                child: Text(tr('unlock')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
