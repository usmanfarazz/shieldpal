import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/password_checker.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _c = TextEditingController();
  bool _hide = true;
  bool _checking = false;
  PasswordReport? _r;

  void _live(String v) => setState(() => _r = v.isEmpty ? null : PasswordChecker.analyze(v));

  Future<void> _breach() async {
    setState(() => _checking = true);
    final n = await PasswordChecker.breachCount(_c.text);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _r = PasswordChecker.analyze(_c.text, breachCount: n);
    });
    if (n == null) showSnack(context, tr('offline_error'));
    context.read<AppState>().addCoins(2);
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    const colors = [dangerRed, Color(0xFFF97316), warnAmber, Color(0xFF84CC16), safeGreen];
    return Scaffold(
      appBar: AppBar(title: Text(tr('tool_password'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr('password_intro')),
        const SizedBox(height: 12),
        TextField(
          controller: _c,
          obscureText: _hide,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: _live,
          decoration: InputDecoration(
            hintText: tr('password_hint'),
            prefixIcon: const Icon(Icons.password_rounded),
            suffixIcon: IconButton(
              icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (r != null) ...[
          Row(children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= r.strength ? colors[r.strength] : Colors.grey.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Text(tr('pw_strength_${r.strength}'),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colors[r.strength])),
          Text(tr('crack_time', {'x': r.crackTime})),
          if (r.breachCount != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                r.breachCount! > 0 ? tr('pw_breached', {'x': r.breachCount}) : tr('pw_not_breached'),
                style: TextStyle(fontWeight: FontWeight.w800, color: r.breachCount! > 0 ? dangerRed : safeGreen),
              ),
            ),
          const SizedBox(height: 8),
          for (final tip in r.tips) FindingTile(code: tip, weight: tip == 'p_breached' || tip == 'p_common' ? 40 : 12),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _checking ? null : _breach,
            icon: _checking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.travel_explore_rounded),
            label: Text(tr('check_leaks')),
          ),
          Text(tr('leak_privacy'), style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 20),
        SectionCard(
          title: tr('generator'),
          icon: Icons.casino_rounded,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('generator_sub')),
            const SizedBox(height: 10),
            FilledButton.icon(
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: Text(tr('generate')),
              onPressed: () {
                final pw = PasswordChecker.generate();
                _c.text = pw;
                _live(pw);
                Clipboard.setData(ClipboardData(text: pw));
                showSnack(context, tr('generated_copied'));
              },
            ),
          ]),
        ),
      ]),
    );
  }
}
