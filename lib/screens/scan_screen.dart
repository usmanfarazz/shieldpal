import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/device_bridge.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _radar = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  final _steps = const ['step_lock', 'step_system', 'step_apps', 'step_spy', 'step_network', 'step_google'];
  int _step = 0;
  bool _done = false;
  DeviceAudit? _audit;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _done = false;
      _step = 0;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (_step < _steps.length - 1) setState(() => _step++);
    });
    // Run the audit while the radar animation plays for at least ~4 s (it's fun :)
    final results = await Future.wait<Object?>([
      DeviceBridge.instance.runAudit(),
      Future<void>.delayed(const Duration(milliseconds: 3900)),
    ]);
    if (!mounted) return;
    final audit = results.first as DeviceAudit? ?? _fallbackAudit();
    _ticker?.cancel();
    if (!mounted) return;
    final app = context.read<AppState>();
    app.setAudit(audit);
    app.addCoins(5);
    setState(() {
      _audit = audit;
      _done = true;
      _step = _steps.length;
    });
    if (audit.score < 60 && app.voiceAlerts) app.say(tr('speak_scan_bad', {'pet': app.petName}));
  }

  /// iPhone / computer: apps cannot inspect other apps there, so ShieldPal
  /// checks only what is possible and explains the rest.
  DeviceAudit _fallbackAudit() {
    final app = context.read<AppState>();
    return DeviceAudit([
      AuditCheck('platform_limited', 'unknown', '', null),
      AuditCheck('app_lock', app.appLock ? 'ok' : 'warn', '', 'open_app_lock'),
      AuditCheck('two_fa', app.totp.isNotEmpty ? 'ok' : 'warn', '', 'open_2fa'),
      AuditCheck('family_code', app.circles.isNotEmpty ? 'ok' : 'warn', '', 'open_family'),
    ], [], 0, []);
  }

  @override
  void dispose() {
    _radar.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('deep_scan'))),
      body: _done && _audit != null ? _results(context, _audit!) : _scanning(context),
    );
  }

  Widget _scanning(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        Center(
          child: AnimatedBuilder(
            animation: _radar,
            builder: (_, _) => CustomPaint(size: const Size.square(240), painter: _RadarPainter(_radar.value)),
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < _steps.length; i++)
          ListTile(
            leading: i < _step
                ? const Icon(Icons.check_circle_rounded, color: safeGreen)
                : i == _step
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                    : const Icon(Icons.radio_button_unchecked_rounded),
            title: Text(tr(_steps[i])),
          ),
      ],
    );
  }

  Widget _results(BuildContext context, DeviceAudit a) {
    final score = a.score;
    final color = score >= 80 ? safeGreen : score >= 55 ? warnAmber : dangerRed;
    final problems = a.checks.where((c) => c.status == 'bad' || c.status == 'warn').length + a.riskyApps.length;
    return RefreshIndicator(
      onRefresh: _run,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Center(child: ScoreRing(value: score, color: color, size: 140, label: tr('safety_score'))),
          const SizedBox(height: 8),
          Center(
            child: Text(
              problems == 0 ? tr('scan_all_good') : tr('scan_found', {'x': problems}),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (a.appsScanned > 0)
            Center(child: Text(tr('apps_scanned', {'x': a.appsScanned}), style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 12),
          if (a.harmfulByGoogle.isNotEmpty)
            SectionCard(
              title: tr('google_harmful'),
              icon: Icons.coronavirus_rounded,
              child: Column(children: [
                for (final p in a.harmfulByGoogle)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.dangerous_rounded, color: dangerRed),
                    title: Text(p),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: dangerRed),
                      onPressed: () => DeviceBridge.instance.uninstall(p),
                      child: Text(tr('remove')),
                    ),
                  ),
              ]),
            ),
          if (a.riskyApps.isNotEmpty)
            SectionCard(
              title: tr('risky_apps'),
              icon: Icons.apps_rounded,
              child: Column(children: [
                Text(tr('risky_apps_sub')),
                const SizedBox(height: 6),
                for (final r in a.riskyApps) _appTile(context, r),
              ]),
            ),
          SectionCard(
            title: tr('checkup'),
            icon: Icons.fact_check_rounded,
            child: Column(children: [for (final c in a.checks) _checkTile(context, c)]),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _run, icon: const Icon(Icons.refresh_rounded), label: Text(tr('scan_again'))),
        ],
      ),
    );
  }

  Widget _checkTile(BuildContext context, AuditCheck c) {
    final (icon, color) = switch (c.status) {
      'ok' => (Icons.check_circle_rounded, safeGreen),
      'warn' => (Icons.error_rounded, warnAmber),
      'bad' => (Icons.cancel_rounded, dangerRed),
      _ => (Icons.help_rounded, Colors.blueGrey),
    };
    final title = tr('chk_${c.id}_${c.status == 'ok' ? 'ok' : 'bad'}', {'x': c.detail});
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: c.status == 'ok' ? null : Text(tr('chk_${c.id}_tip')),
      trailing: c.fix != null && c.status != 'ok'
          ? TextButton(onPressed: () => _fix(c.fix!), child: Text(tr('fix')))
          : null,
    );
  }

  void _fix(String action) {
    // In-app destinations; everything else opens the right Android setting.
    switch (action) {
      case 'open_app_lock':
      case 'open_2fa':
      case 'open_family':
        showSnack(context, tr('fix_in_app_${action.substring(5)}'));
      default:
        DeviceBridge.instance.runFix(action);
    }
  }

  Widget _appTile(BuildContext context, AppRisk r) {
    final c = r.score >= 70 ? dangerRed : r.score >= 40 ? warnAmber : Colors.blueGrey;
    return Card(
      color: c.withValues(alpha: 0.07),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: c.withValues(alpha: 0.2), child: Text(r.label.isEmpty ? '?' : r.label[0].toUpperCase())),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(r.package, style: const TextStyle(fontSize: 11)),
              ]),
            ),
            Text('${r.score}', style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
          const SizedBox(height: 6),
          for (final reason in r.reasons)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• ${tr(reason)}', style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: dangerRed),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text(tr('remove')),
              onPressed: () {
                // Device-admin apps block uninstalling until admin is removed.
                if (r.isAdmin) {
                  showSnack(context, tr('admin_first'));
                  DeviceBridge.instance.runFix('device_admin');
                } else {
                  DeviceBridge.instance.uninstall(r.package);
                }
              },
            ),
            OutlinedButton(onPressed: () => DeviceBridge.instance.openAppDetails(r.package), child: Text(tr('details'))),
          ]),
        ]),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  _RadarPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ring = Paint()
      ..color = brandBlue.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r, Paint()..color = brandBlue.withValues(alpha: 0.08));
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(c, r * i / 4, ring);
    }
    canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), ring);
    canvas.drawLine(c.translate(0, -r), c.translate(0, r), ring);
    final a = t * 2 * pi;
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: a - 1.2,
        endAngle: a,
        colors: [brandAqua.withValues(alpha: 0), brandAqua.withValues(alpha: 0.7)],
        transform: GradientRotation(0),
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), a - 1.2, 1.2, true, sweep);
    canvas.drawLine(c, c + Offset(cos(a), sin(a)) * r, Paint()
      ..color = brandAqua
      ..strokeWidth = 3);
    final rnd = Random(7);
    for (var i = 0; i < 9; i++) {
      final ang = rnd.nextDouble() * 2 * pi;
      final dist = r * (0.2 + rnd.nextDouble() * 0.75);
      var diff = (a - ang) % (2 * pi);
      final glow = diff < 1.5 ? 1 - diff / 1.5 : 0.0;
      canvas.drawCircle(c + Offset(cos(ang), sin(ang)) * dist, 4 + glow * 3,
          Paint()..color = (i % 4 == 0 ? brandPink : brandAqua).withValues(alpha: 0.2 + glow * 0.8));
    }
    final tp = TextPainter(text: const TextSpan(text: '🛡️', style: TextStyle(fontSize: 42)), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t;
}
