import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/device_bridge.dart';
import '../core/link_scanner.dart';
import '../core/scam_engine.dart';
import '../core/url_analyzer.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'link_check_screen.dart';

class MessageCheckScreen extends StatefulWidget {
  final String? initial;
  const MessageCheckScreen({super.key, this.initial});

  @override
  State<MessageCheckScreen> createState() => _MessageCheckScreenState();
}

class _MessageCheckScreenState extends State<MessageCheckScreen> {
  late final TextEditingController _c = TextEditingController(text: widget.initial ?? '');
  MessageReport? _r;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initial ?? '').isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    final text = _c.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final r = ScamEngine.instance.analyze(text);
    final app = context.read<AppState>();
    app.addCoins(2);
    if (r.score >= 60) {
      app.addThreat(
        Threat(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          time: DateTime.now(),
          kind: 'message',
          sourceApp: 'ShieldPal',
          text: text,
          url: r.links.isEmpty ? '' : r.links.first.url,
          score: r.score,
        ),
        speak: true,
      );
    }
    setState(() => _r = r);
    if (r.links.isNotEmpty) _cloudCheck(r);
  }

  /// Links inside the message also get a cloud second opinion (Cloudflare + Google key).
  Future<void> _cloudCheck(MessageReport r) async {
    final app = context.read<AppState>();
    setState(() => _checking = true);
    var worst = 0;
    var flagged = false;
    for (final l in r.links.take(3)) {
      final scan = await LinkScanner.fullScan(l.url, deep: false, cloud: app.cloudCheck);
      if (scan.score > worst) worst = scan.score;
      if (scan.cloudFlagged == true || scan.googleFlagged == true) flagged = true;
    }
    if (!mounted || _r?.text != r.text) return;
    setState(() => _checking = false);
    if (worst > r.score) {
      final updated = MessageReport(
        r.text,
        worst,
        r.aiProbability,
        [...r.signals, if (flagged) const Signal('s_cloud_flagged', 40)],
        r.links,
      );
      setState(() => _r = updated);
      if (worst >= 60) {
        app.addThreat(
          Threat(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            time: DateTime.now(),
            kind: 'message',
            sourceApp: 'ShieldPal',
            text: r.text,
            url: r.links.first.url,
            score: worst,
          ),
          speak: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: Text(tr('tool_msg'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('msg_intro')),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            minLines: 4,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: tr('msg_hint'),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_rounded),
                tooltip: tr('paste'),
                onPressed: () async {
                  final d = await Clipboard.getData(Clipboard.kTextPlain);
                  if (d?.text != null) _c.text = d!.text!;
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          GradientButton(label: tr('analyze'), icon: Icons.psychology_rounded, onPressed: _check),
          const SizedBox(height: 8),
          Text(tr('share_tip'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (r != null) ...[
            VerdictBanner(
              verdict: r.verdict,
              score: r.score,
              subtitle: tr(r.verdict == Verdict.safe ? 'msg_safe_sub' : 'msg_bad_sub'),
            ),
            if (_checking) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: LinearProgressIndicator(minHeight: 4)),
            SectionCard(
              title: tr('ai_says'),
              icon: Icons.auto_awesome_rounded,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('ai_prob', {'x': (r.aiProbability * 100).round()})),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: r.aiProbability,
                    minHeight: 10,
                    color: verdictColor(verdictForScore((r.aiProbability * 100).round())),
                  ),
                ),
              ]),
            ),
            SectionCard(
              title: tr('red_flags'),
              icon: Icons.flag_rounded,
              child: r.signals.isEmpty
                  ? Text(tr('no_red_flags'))
                  : Column(children: [for (final s in r.signals) FindingTile(code: s.code, weight: s.weight)]),
            ),
            if (r.links.isNotEmpty)
              SectionCard(
                title: tr('links_inside'),
                icon: Icons.link_rounded,
                child: Column(children: [
                  for (final l in r.links)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(verdictIcon(l.verdict), color: verdictColor(l.verdict)),
                      title: Text(l.url, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(verdictTitle(l.verdict)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => LinkCheckScreen(initial: l.url, autoStart: true))),
                    ),
                ]),
              ),
            SectionCard(
              title: tr('teach_title'),
              icon: Icons.school_rounded,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('teach_body')),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.dangerous_rounded, color: dangerRed),
                    label: Text(tr('teach_scam')),
                    onPressed: () {
                      context.read<AppState>().teachMessage(r.text, true);
                      showSnack(context, tr('teach_thanks'));
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.verified_rounded, color: safeGreen),
                    label: Text(tr('teach_safe')),
                    onPressed: () {
                      context.read<AppState>().teachMessage(r.text, false);
                      showSnack(context, tr('teach_thanks'));
                    },
                  ),
                ]),
                const SizedBox(height: 4),
                Text(tr('teach_count', {'x': context.watch<AppState>().userExamples.length}), style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            if (r.verdict != Verdict.safe)
              SectionCard(
                title: tr('what_to_do'),
                icon: Icons.health_and_safety_rounded,
                child: Text(tr('what_to_do_body')),
              ),
          ],
        ],
      ),
    );
  }
}
