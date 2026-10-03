import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/device_bridge.dart';
import '../core/tips.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'link_check_screen.dart';
import 'message_check_screen.dart';

class ThreatsScreen extends StatefulWidget {
  const ThreatsScreen({super.key});

  @override
  State<ThreatsScreen> createState() => _ThreatsScreenState();
}

class _ThreatsScreenState extends State<ThreatsScreen> {
  String _filter = 'all'; // all | link | message | app | dns | qr

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final shown = app.threats.where((t) => _filter == 'all' || t.kind == _filter).toList();
    final open = app.threats.where((t) => !t.resolved && t.score >= 60).length;
    const filters = ['all', 'link', 'message', 'app', 'dns', 'qr'];
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('threat_log')),
        actions: [
          if (open > 0)
            IconButton(
              tooltip: tr('th_mark_all'),
              icon: const Icon(Icons.done_all_rounded),
              onPressed: () {
                for (final t in app.threats.where((t) => !t.resolved)) {
                  t.resolved = true;
                }
                app.update((_) {});
                showSnack(context, tr('th_all_handled'));
              },
            ),
          if (app.threats.isNotEmpty)
            IconButton(
              tooltip: tr('clear_all'),
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(tr('clear_all')),
                    content: Text(tr('clear_all_q')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('cancel'))),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('ok'))),
                    ],
                  ),
                );
                if (ok == true) app.clearThreats();
              },
            ),
        ],
      ),
      body: Column(children: [
        if (app.threats.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              Expanded(
                child: Text(tr('th_summary', {'x': app.threats.length, 'y': open}),
                    style: TextStyle(fontWeight: FontWeight.w700, color: open > 0 ? dangerRed : safeGreen)),
              ),
            ]),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8, bottom: 4),
                    child: ChoiceChip(
                      label: Text(f == 'all' ? tr('th_filter_all') : '${ThreatTile.emojiFor(f)} ${tr('th_filter_$f')}'),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
        ],
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🎉', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 12),
                      Text(tr('no_threats', {'pet': app.petName}), textAlign: TextAlign.center),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => Dismissible(
                    key: ValueKey(shown[i].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: dangerRed.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(22)),
                      child: const Icon(Icons.delete_rounded, color: dangerRed),
                    ),
                    onDismissed: (_) {
                      app.threats.removeWhere((t) => t.id == shown[i].id);
                      app.update((_) {});
                    },
                    child: Card(child: ThreatTile(threat: shown[i])),
                  ),
                ),
        ),
        const _TipOfDay(),
      ]),
    );
  }
}

/// "Cyber tip of the day" shown at the bottom of the Threat Log.
class _TipOfDay extends StatelessWidget {
  const _TipOfDay();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [brandBlue.withValues(alpha: 0.16), brandAqua.withValues(alpha: 0.16)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💡', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('tip_of_day'), style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(Tips.tipOfDay()),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ThreatTile extends StatelessWidget {
  final Threat threat;
  const ThreatTile({super.key, required this.threat});

  static String emojiFor(String kind) => switch (kind) {
        'link' => '🔗',
        'app' => '📦',
        'dns' => '🌐',
        'qr' => '📷',
        _ => '💬',
      };

  static String titleFor(Threat t) {
    final where = t.sourceApp.isEmpty ? '' : t.sourceApp;
    return switch (t.kind) {
      'link' => tr('th_link', {'app': where}),
      'app' => tr('th_app', {'app': t.chat.isEmpty ? t.sourceApp : t.chat}),
      'dns' => tr('th_dns'),
      'qr' => tr('th_qr'),
      _ => tr('th_msg', {'app': where}),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = verdictColor(verdictForScore(threat.score));
    final when = TimeOfDay.fromDateTime(threat.time).format(context);
    final date = '${threat.time.day}/${threat.time.month}';
    return ListTile(
      leading: CircleAvatar(backgroundColor: c.withValues(alpha: 0.15), child: Text(emojiFor(threat.kind))),
      title: Text(titleFor(threat),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: threat.resolved ? TextDecoration.lineThrough : null,
          )),
      subtitle: Text(
        [
          if (threat.chat.isNotEmpty && threat.kind != 'app') '${tr('from_chat')}: ${threat.chat}',
          if (threat.kind == 'app')
            threat.text.split(', ').where((e) => e.isNotEmpty).map((e) => tr(e)).join(', ')
          else if (threat.url.isNotEmpty)
            threat.url
          else
            threat.text,
        ].join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${threat.score}', style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 16)),
          Text('$date $when', style: const TextStyle(fontSize: 11)),
        ],
      ),
      onTap: () => _details(context),
    );
  }

  void _details(BuildContext context) {
    final app = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${emojiFor(threat.kind)}  ${titleFor(threat)}', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (threat.sourceApp.isNotEmpty) Text('${tr('source_app')}: ${threat.sourceApp}'),
            if (threat.chat.isNotEmpty) Text('${tr('from_chat')}: ${threat.chat}'),
            const SizedBox(height: 10),
            if (threat.text.isNotEmpty && threat.kind != 'app')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(c).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(threat.text),
              ),
            if (threat.kind == 'app')
              for (final r in threat.text.split(', ').where((e) => e.isNotEmpty)) Text('• ${tr(r)}'),
            if (threat.url.isNotEmpty && threat.kind != 'app') ...[
              const SizedBox(height: 8),
              SelectableText(threat.url, style: const TextStyle(color: dangerRed, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 10),
            Text(tr('dont_open_tip')),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (threat.url.isNotEmpty)
                FilledButton.icon(
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: Text(tr('deep_check')),
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LinkCheckScreen(initial: threat.url, autoStart: true)));
                  },
                ),
              if (threat.kind == 'message' && threat.text.isNotEmpty)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.psychology_rounded),
                  label: Text(tr('analyze')),
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessageCheckScreen(initial: threat.text)));
                  },
                ),
              if (threat.kind == 'app' && threat.chat.isNotEmpty && DeviceBridge.isAndroid)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: dangerRed),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: Text(tr('remove_app')),
                  onPressed: () => DeviceBridge.instance.uninstall(threat.url),
                ),
              if (!threat.resolved)
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: Text(tr('mark_handled')),
                  onPressed: () {
                    app.resolveThreat(threat);
                    Navigator.pop(c);
                  },
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
