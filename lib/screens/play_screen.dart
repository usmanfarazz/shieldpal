import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pet_view.dart';
import 'quiz_screen.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Row(children: [
          Expanded(child: Text(tr('tab_play'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
          CoinBadge(coins: app.coins),
        ]),
        const SizedBox(height: 10),
        // Quiz banner
        Material(
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFF4D8D), Color(0xFF6A5CFF)]),
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuizScreen())),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  const Text('🕵️', style: TextStyle(fontSize: 52)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('quiz_title'),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text(tr('quiz_sub'), style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 6),
                      Text(tr('quiz_best', {'x': app.quizBest}),
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 44),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Pet wardrobe preview
        SectionCard(
          title: tr('wardrobe', {'pet': app.petName}),
          icon: Icons.checkroom_rounded,
          child: Column(children: [
            Center(child: PetView(mood: PetMood.happy, look: app.look, size: 170)),
            Text(tr('level_x', {'x': app.level}), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: (app.xp % 100) / 100, borderRadius: BorderRadius.circular(6)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
              children: [for (final item in shopItems) _ShopTile(item: item)],
            ),
          ]),
        ),
        // Achievements
        SectionCard(
          title: tr('achievements'),
          icon: Icons.emoji_events_rounded,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in achievements)
              Opacity(
                opacity: app.unlocked.contains(a.id) ? 1 : 0.55,
                child: ActionChip(
                  avatar: Text(a.emoji),
                  label: Text(tr(a.id)),
                  side: BorderSide(color: app.unlocked.contains(a.id) ? const Color(0xFFFACC15) : Colors.grey.withValues(alpha: 0.4), width: 2),
                  onPressed: () => _showAchievement(context, app, a),
                ),
              ),
          ]),
        ),
        SectionCard(
          title: tr('stats'),
          icon: Icons.insights_rounded,
          child: Column(children: [
            _stat('🔗', tr('stat_links'), app.linksChecked),
            _stat('🛡️', tr('stat_scams'), app.scamsCaught),
            _stat('🧠', tr('stat_quiz'), app.quizCorrect),
            _stat('🔥', tr('stat_streak'), app.streak),
          ]),
        ),
      ]),
    );
  }

  void _showAchievement(BuildContext context, AppState app, Achievement a) {
    final done = app.unlocked.contains(a.id);
    final (cur, target) = app.achievementProgress(a.id);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(a.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 6),
            Text(tr(a.id), style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(tr('${a.id}_how'), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            if (!done) ...[
              LinearProgressIndicator(value: target == 0 ? 0 : cur / target, minHeight: 10, borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 6),
              Text('${tr('ach_progress')}: $cur / $target'),
            ] else
              Text('✅ ${tr('ach_done')}', style: const TextStyle(fontWeight: FontWeight.w800, color: safeGreen)),
            const SizedBox(height: 8),
            Text('${tr('ach_reward')}: +${a.reward} 🪙'),
          ]),
        ),
      ),
    );
  }

  Widget _stat(String e, String k, int v) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Text(e, style: const TextStyle(fontSize: 22)),
        title: Text(k),
        trailing: Text('$v', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      );
}

class _ShopTile extends StatelessWidget {
  final ShopItem item;
  const _ShopTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final owned = app.owned.contains(item.id);
    final on = owned && app.isEquipped(item);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (owned) {
          app.equip(item);
        } else if (!app.buy(item)) {
          showSnack(context, tr('need_coins', {'x': item.price - app.coins}));
        } else {
          showSnack(context, tr('bought'));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: on ? brandBlue.withValues(alpha: 0.18) : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(color: on ? brandBlue : Colors.transparent, width: 2),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (item.slot == 'skin')
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: petSkins[int.parse(item.value)]),
              ),
            )
          else
            Text(item.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 4),
          Text(owned ? (on ? tr('wearing') : tr('owned')) : '🪙 ${item.price}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
