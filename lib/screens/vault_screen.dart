import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/totp.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'family_screen.dart';
import 'password_screen.dart';
import 'qr_scan_screen.dart';

/// Vault = built-in 2FA authenticator (TOTP), plus shortcuts to the
/// family safe-word and password tools. Secrets live in encrypted storage.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    final raw = await scanQrRaw(context);
    if (raw == null || !mounted) return;
    final acc = TotpAccount.fromUri(raw);
    if (acc == null) {
      showSnack(context, tr('q_otp_bad'), color: dangerRed);
      return;
    }
    await context.read<AppState>().addTotp(acc);
    if (mounted) showSnack(context, tr('added'));
  }

  Future<void> _manual() async {
    final issuer = TextEditingController();
    final label = TextEditingController();
    final secret = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('add_manual')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: issuer, decoration: InputDecoration(labelText: tr('issuer'))),
            const SizedBox(height: 8),
            TextField(controller: label, decoration: InputDecoration(labelText: tr('account'))),
            const SizedBox(height: 8),
            TextField(controller: secret, decoration: InputDecoration(labelText: tr('secret_key'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('add'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final s = secret.text.replaceAll(' ', '').toUpperCase();
    if (Totp.base32Decode(s) == null) {
      showSnack(context, tr('bad_secret'), color: dangerRed);
      return;
    }
    await context.read<AppState>().addTotp(TotpAccount(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          issuer: issuer.text.trim(),
          label: label.text.trim(),
          secret: s,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Text(tr('tab_vault'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        Text(tr('vault_sub')),
        const SizedBox(height: 12),
        if (app.totp.isEmpty)
          SectionCard(
            title: tr('what_is_2fa'),
            icon: Icons.verified_user_rounded,
            child: Text(tr('what_is_2fa_body')),
          ),
        for (final a in app.totp)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: brandBlue.withValues(alpha: 0.15),
                child: Text((a.issuer.isNotEmpty ? a.issuer : a.label).characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              title: Text(
                _fmt(a.codeAt(now)),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              subtitle: Text([a.issuer, a.label].where((e) => e.isNotEmpty).join(' · ')),
              trailing: SizedBox(
                width: 34,
                height: 34,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: a.secondsLeft(now) / a.period,
                    strokeWidth: 4,
                    color: a.secondsLeft(now) <= 5 ? dangerRed : brandBlue,
                  ),
                  Text('${a.secondsLeft(now)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: a.codeAt(DateTime.now())));
                showSnack(context, tr('code_copied'));
              },
              onLongPress: () async {
                final del = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text(tr('delete_account_q')),
                    content: Text(tr('delete_account_body')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('cancel'))),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: dangerRed),
                        onPressed: () => Navigator.pop(d, true),
                        child: Text(tr('delete')),
                      ),
                    ],
                  ),
                );
                if (del == true && context.mounted) context.read<AppState>().removeTotp(a);
              },
            ),
          ),
        const SizedBox(height: 10),
        GradientButton(label: tr('scan_2fa_qr'), icon: Icons.qr_code_scanner_rounded, onPressed: _scan),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _manual, icon: const Icon(Icons.keyboard_rounded), label: Text(tr('add_manual'))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: SizedBox(height: 130, child: ToolTile(
              emoji: '👨‍👩‍👧',
              title: tr('family_code'),
              subtitle: tr('family_code_sub'),
              colors: const [Color(0xFFC86BFA), Color(0xFFFF9AD5)],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FamilyScreen())),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(height: 130, child: ToolTile(
              emoji: '🔑',
              title: tr('tool_password'),
              subtitle: tr('tool_password_sub'),
              colors: const [Color(0xFF3D4A5C), Color(0xFF6B7A90)],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PasswordScreen())),
            )),
          ),
        ]),
      ]),
    );
  }

  String _fmt(String code) => code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
}
