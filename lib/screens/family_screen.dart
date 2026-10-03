import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/family_code.dart';
import '../core/totp.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'qr_scan_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    final c = TextEditingController(text: tr('my_family'));
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('new_circle')),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(tr('create'))),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final circle = FamilyCircle(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name, secret: Totp.randomSecret());
    await context.read<AppState>().addCircle(circle);
    if (mounted) _showQr(circle);
  }

  Future<void> _join() async {
    final raw = await scanQrRaw(context);
    if (raw == null || !mounted) return;
    final c = FamilyCircle.fromQr(raw);
    if (c == null) {
      showSnack(context, tr('q_family_bad'), color: dangerRed);
      return;
    }
    await context.read<AppState>().addCircle(c);
    if (mounted) showSnack(context, tr('joined', {'x': c.name}));
  }

  void _showQr(FamilyCircle c) {
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('invite_title', {'x': c.name})),
        content: SizedBox(
          width: 260,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: QrImageView(data: c.toQr(), size: 220),
            ),
            const SizedBox(height: 10),
            Text(tr('invite_body')),
          ]),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(d), child: Text(tr('done')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(tr('family_code'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SectionCard(
          title: tr('family_how'),
          icon: Icons.record_voice_over_rounded,
          child: Text(tr('family_how_body')),
        ),
        for (final c in app.circles)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  const Text('👨‍👩‍👧', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                  IconButton(icon: const Icon(Icons.qr_code_rounded), tooltip: tr('invite'), onPressed: () => _showQr(c)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => context.read<AppState>().removeCircle(c),
                  ),
                ]),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(c.codeAt(now).join('  '), style: const TextStyle(fontSize: 56)),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: c.secondsLeft(now) / c.period, borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 4),
                Text(tr('changes_in', {'x': '${c.secondsLeft(now) ~/ 60}:${(c.secondsLeft(now) % 60).toString().padLeft(2, '0')}'})),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        GradientButton(label: tr('new_circle'), icon: Icons.add_rounded, onPressed: _create),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _join, icon: const Icon(Icons.qr_code_scanner_rounded), label: Text(tr('join_family'))),
      ]),
    );
  }
}
