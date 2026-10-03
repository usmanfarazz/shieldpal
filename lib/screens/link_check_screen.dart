import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/device_bridge.dart';
import '../core/link_scanner.dart';
import '../core/url_analyzer.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class LinkCheckScreen extends StatefulWidget {
  final String? initial;
  final bool autoStart;
  final bool openIfSafe; // Safe Link Gate: open clean links straight away
  const LinkCheckScreen({super.key, this.initial, this.autoStart = false, this.openIfSafe = false});

  @override
  State<LinkCheckScreen> createState() => _LinkCheckScreenState();
}

class _LinkCheckScreenState extends State<LinkCheckScreen> {
  late final TextEditingController _c = TextEditingController(text: widget.initial ?? '');
  bool _busy = false;
  bool _deep = true;
  String _stage = '';
  LinkScanResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart && (widget.initial ?? '').isNotEmpty) {
      if (widget.openIfSafe) _deep = false; // fast path: no 60 s sandbox wait
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final text = d?.text ?? '';
    final urls = UrlAnalyzer.extractUrls(text);
    _c.text = urls.isNotEmpty ? urls.first : text;
  }

  Future<void> _check() async {
    final url = _c.text.trim();
    if (url.isEmpty) return;
    FocusScope.of(context).unfocus();
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _result = null;
      _stage = 'expand';
    });
    final r = await LinkScanner.fullScan(url, deep: _deep, cloud: app.cloudCheck, onProgress: (s) {
      if (mounted) setState(() => _stage = s);
    });
    if (!mounted) return;
    app.recordLinkCheck(r.score);
    if (r.score >= 60) {
      app.addThreat(
        Threat(
          id: 'lk_${DateTime.now().millisecondsSinceEpoch}',
          time: DateTime.now(),
          kind: 'link',
          sourceApp: 'ShieldPal',
          url: url,
          score: r.score,
        ),
        speak: true,
      );
    }
    setState(() {
      _busy = false;
      _result = r;
    });
    if (widget.openIfSafe && r.verdict == Verdict.safe) {
      final uri = UrlAnalyzer.normalise(r.expandedUrl ?? url);
      if (uri != null) {
        await DeviceBridge.instance.openLink(uri);
        if (mounted) Navigator.of(context).maybePop();
      }
    }
  }

  Future<void> _openAnyway(String url) async {
    final r = _result;
    if (r != null && r.verdict != Verdict.safe) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: dangerRed, size: 40),
          title: Text(tr('open_anyway_q')),
          content: Text(tr('open_anyway_body')),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('stay_safe'))),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('open_anyway'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    final uri = UrlAnalyzer.normalise(url);
    if (uri != null) await DeviceBridge.instance.openLink(uri);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text(tr('tool_link'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('link_intro')),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'https://…',
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: IconButton(icon: const Icon(Icons.content_paste_rounded), tooltip: tr('paste'), onPressed: _paste),
            ),
            onSubmitted: (_) => _check(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _deep,
            onChanged: (v) => setState(() => _deep = v),
            title: Text(tr('sandbox_toggle')),
            subtitle: Text(tr('sandbox_toggle_sub')),
          ),
          GradientButton(label: tr('check_link'), icon: Icons.travel_explore_rounded, onPressed: _busy ? null : _check),
          const SizedBox(height: 16),
          if (_busy)
            SectionCard(
              child: Row(children: [
                const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(width: 14),
                Expanded(child: Text(tr('stage_${_stage.endsWith('s') && _stage.length <= 4 ? 'sandbox' : _stage}'))),
              ]),
            ),
          if (r != null) ..._resultWidgets(context, r),
        ],
      ),
    );
  }

  List<Widget> _resultWidgets(BuildContext context, LinkScanResult r) {
    final findings = [...r.offline.findings, ...?r.expandedReport?.findings];
    return [
      VerdictBanner(
        verdict: r.verdict,
        score: r.score,
        subtitle: r.verdict == Verdict.safe ? tr('link_safe_sub') : tr('link_bad_sub'),
      ),
      const SizedBox(height: 8),
      if (r.expandedUrl != null)
        SectionCard(
          title: tr('real_destination'),
          icon: Icons.alt_route_rounded,
          child: SelectableText(r.expandedUrl!, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      SectionCard(
        title: tr('what_we_found'),
        icon: Icons.manage_search_rounded,
        child: findings.isEmpty
            ? Text(tr('no_red_flags'))
            : Column(children: [for (final f in findings) FindingTile(code: f.code, detail: f.detail, weight: f.weight)]),
      ),
      SectionCard(
        title: tr('cloud_check_title'),
        icon: Icons.cloud_done_rounded,
        child: Text(switch (r.cloudFlagged) {
          true => tr('cloud_flagged'),
          false => tr('cloud_clean'),
          null => tr('cloud_unavailable'),
        }),
      ),
      SectionCard(
        title: 'Google Safe Browsing',
        icon: Icons.g_mobiledata_rounded,
        child: Text(switch (r.googleFlagged) {
          true => tr('google_flagged', {'x': r.googleThreats.join(', ')}),
          false => tr('google_clean'),
          null => tr('google_not_set'),
        }),
      ),
      if (_deep)
        SectionCard(
          title: tr('sandbox_title'),
          icon: Icons.science_rounded,
          child: r.sandboxScreenshot == null
              ? Text(tr('n_no_sandbox'))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.sandboxMalicious == true ? tr('sandbox_malicious') : tr('sandbox_clean'),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: r.sandboxMalicious == true ? dangerRed : safeGreen)),
                  if (r.sandboxTitle != null) Text('${tr('page_title')}: ${r.sandboxTitle}'),
                  if (r.sandboxFinalUrl != null) Text('${tr('final_url')}: ${r.sandboxFinalUrl}'),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      r.sandboxScreenshot!,
                      errorBuilder: (_, _, _) => Text(tr('screenshot_pending')),
                    ),
                  ),
                  Text(tr('screenshot_note'), style: Theme.of(context).textTheme.bodySmall),
                ]),
        ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded),
            label: Text(tr('copy')),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: r.offline.url));
              showSnack(context, tr('copied'));
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: r.verdict == Verdict.safe
              ? FilledButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(tr('open_link')),
                  onPressed: () => _openAnyway(r.expandedUrl ?? r.offline.url),
                )
              : TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(tr('open_anyway')),
                  onPressed: () => _openAnyway(r.expandedUrl ?? r.offline.url),
                ),
        ),
      ]),
    ];
  }
}
