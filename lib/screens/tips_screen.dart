import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/tips.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Today's cyber tip plus the whole tip library. Reading today's tip earns coins.
class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  int _reward = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final r = context.read<AppState>().readTipToday();
      if (r > 0) setState(() => _reward = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tips = Tips.all;
    final today = Tips.dayIndex() % tips.length;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('tips_title'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: brandGradient, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('💡', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('tip_of_day'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
            ]),
            const SizedBox(height: 12),
            Text(tips[today], style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.35)),
            const SizedBox(height: 12),
            Row(children: [
              if (_reward > 0)
                Chip(label: Text(tr('tip_reward', {'x': _reward})), backgroundColor: Colors.white)
              else if (context.watch<AppState>().tipReadToday)
                Chip(label: Text('✅ ${tr('tip_read')}'), backgroundColor: Colors.white),
              const Spacer(),
              IconButton(
                tooltip: tr('copy'),
                color: Colors.white,
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: tips[today]));
                  showSnack(context, tr('copied'));
                },
              ),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
          child: Text(tr('tips_all'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ),
        for (var i = 0; i < tips.length; i++)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (i == today ? brandBlue : Colors.grey).withValues(alpha: 0.15),
                child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: i == today ? brandBlue : null)),
              ),
              title: Text(tips[i]),
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: tips[i]));
                showSnack(context, tr('copied'));
              },
            ),
          ),
      ]),
    );
  }
}
