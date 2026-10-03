import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../core/device_bridge.dart';
import '../core/link_scanner.dart';
import '../core/qr_analyzer.dart';
import '../core/url_analyzer.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'link_check_screen.dart';

bool get cameraScanSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Scans a QR code and returns its raw text (used by 2FA and Family pairing).
Future<String?> scanQrRaw(BuildContext context) {
  return Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _RawScanner()));
}

class _RawScanner extends StatefulWidget {
  const _RawScanner();
  @override
  State<_RawScanner> createState() => _RawScannerState();
}

class _RawScannerState extends State<_RawScanner> {
  bool _done = false;
  final _manual = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('scan_qr'))),
      body: cameraScanSupported
          ? Stack(children: [
              MobileScanner(onDetect: (cap) {
                final v = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
                if (v != null && !_done) {
                  _done = true;
                  Navigator.of(context).pop(v);
                }
              }),
              const _ScanFrame(),
            ])
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text(tr('no_camera_paste')),
                const SizedBox(height: 12),
                TextField(controller: _manual, maxLines: 3),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.of(context).pop(_manual.text.trim()), child: Text(tr('ok'))),
              ]),
            ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: brandAqua, width: 4),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }
}

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  QrReport? _report;
  bool _checking = false;
  final _manual = TextEditingController();
  MobileScannerController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (cameraScanSupported) _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _handle(String raw) {
    if (_report != null) return;
    final r = QrAnalyzer.analyze(raw);
    final app = context.read<AppState>();
    app.unlock('a_qr');
    app.addCoins(2);
    if (r.risk >= 60) {
      app.addThreat(
        Threat(
          id: 'qr_${DateTime.now().millisecondsSinceEpoch}',
          time: DateTime.now(),
          kind: 'qr',
          sourceApp: 'QR',
          text: raw,
          url: r.url?.url ?? '',
          score: r.risk,
        ),
        speak: true,
      );
    }
    HapticFeedback.mediumImpact();
    _ctrl?.stop();
    setState(() => _report = r);
    if (r.kind == QrKind.url && r.url != null) _cloudCheck(r);
  }

  /// A QR link that looks clean offline still gets a cloud second opinion
  /// (Cloudflare + your Google key if set) before the user is told it is safe.
  Future<void> _cloudCheck(QrReport r) async {
    final app = context.read<AppState>();
    setState(() => _checking = true);
    final scan = await LinkScanner.fullScan(r.url!.url, deep: false, cloud: app.cloudCheck);
    if (!mounted || _report?.raw != r.raw) return;
    setState(() => _checking = false);
    if (scan.score > r.risk) {
      final updated = QrReport(
        raw: r.raw,
        kind: r.kind,
        risk: scan.score,
        notes: [...r.notes, if (scan.cloudFlagged == true || scan.googleFlagged == true) 'q_cloud_flagged'],
        details: r.details,
        url: r.url,
      );
      setState(() => _report = updated);
      if (scan.score >= 60) {
        app.addThreat(
          Threat(
            id: 'qr_${DateTime.now().millisecondsSinceEpoch}',
            time: DateTime.now(),
            kind: 'qr',
            sourceApp: 'QR',
            text: r.raw,
            url: r.url!.url,
            score: scan.score,
          ),
          speak: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('tool_qr'))),
      body: _report == null ? _scanner(context) : _result(context, _report!),
    );
  }

  Widget _scanner(BuildContext context) {
    if (!cameraScanSupported) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr('no_camera_paste')),
        const SizedBox(height: 12),
        TextField(controller: _manual, maxLines: 4),
        const SizedBox(height: 12),
        GradientButton(label: tr('analyze'), icon: Icons.qr_code_2_rounded, onPressed: () => _handle(_manual.text)),
      ]);
    }
    return Stack(children: [
      MobileScanner(
        controller: _ctrl,
        onDetect: (cap) {
          final v = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
          if (v != null) _handle(v);
        },
      ),
      const _ScanFrame(),
      Positioned(
        left: 16,
        right: 16,
        bottom: 30,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(tr('qr_intro'), textAlign: TextAlign.center),
          ),
        ),
      ),
    ]);
  }

  Widget _result(BuildContext context, QrReport r) {
    final v = verdictForScore(r.risk);
    final kindLabel = tr('qk_${r.kind.name}');
    return ListView(padding: const EdgeInsets.all(16), children: [
      VerdictBanner(verdict: v, score: r.risk, subtitle: kindLabel),
      if (_checking)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: LinearProgressIndicator(minHeight: 4),
        ),
      SectionCard(
        title: tr('qr_contains'),
        icon: Icons.qr_code_rounded,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final n in r.notes) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(tr(n))),
          for (final e in r.details.entries) Text('${tr('qd_${e.key}')}: ${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(r.raw, maxLines: 6),
          ),
        ]),
      ),
      if (r.url != null && r.url!.findings.isNotEmpty)
        SectionCard(
          title: tr('what_we_found'),
          icon: Icons.manage_search_rounded,
          child: Column(children: [for (final f in r.url!.findings) FindingTile(code: f.code, detail: f.detail, weight: f.weight)]),
        ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (r.kind == QrKind.url)
          FilledButton.icon(
            icon: const Icon(Icons.travel_explore_rounded),
            label: Text(tr('deep_check')),
            onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LinkCheckScreen(initial: r.url!.url, autoStart: true))),
          ),
        if (r.kind == QrKind.otpauth && r.totp != null)
          FilledButton.icon(
            icon: const Icon(Icons.key_rounded),
            label: Text(tr('add_to_2fa')),
            onPressed: () async {
              await context.read<AppState>().addTotp(r.totp!);
              if (context.mounted) {
                showSnack(context, tr('added'));
                Navigator.of(context).pop();
              }
            },
          ),
        if (r.kind == QrKind.family && r.family != null)
          FilledButton.icon(
            icon: const Icon(Icons.family_restroom_rounded),
            label: Text(tr('join_family')),
            onPressed: () async {
              await context.read<AppState>().addCircle(r.family!);
              if (context.mounted) {
                showSnack(context, tr('added'));
                Navigator.of(context).pop();
              }
            },
          ),
        if (r.kind == QrKind.url && r.risk < 25 && !_checking)
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(tr('open')),
            onPressed: () {
              final u = UrlAnalyzer.normalise(r.url!.url);
              if (u != null) DeviceBridge.instance.openInBrowser(u);
            },
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_rounded),
          label: Text(tr('copy')),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: r.raw));
            showSnack(context, tr('copied'));
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: Text(tr('scan_again')),
          onPressed: () {
            setState(() => _report = null);
            _ctrl?.start();
          },
        ),
      ]),
    ]);
  }
}
