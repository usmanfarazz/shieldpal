import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/device_bridge.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pet_view.dart';
import 'link_check_screen.dart';
import 'message_check_screen.dart';
import 'number_check_screen.dart';
import 'protection_screen.dart';
import 'qr_scan_screen.dart';
import 'scan_screen.dart';
import 'threats_screen.dart';
import 'tips_screen.dart';
import '../core/tips.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tipIndex = Random().nextInt(10);
  String? _bubble;

  void _petTapped(AppState app) {
    final lines = switch (app.mood) {
      PetMood.happy => ['pet_happy_1', 'pet_happy_2', 'pet_happy_3'],
      PetMood.ok => ['pet_ok_1', 'pet_ok_2'],
      PetMood.worried => ['pet_worried_1', 'pet_worried_2'],
      PetMood.sick => ['pet_sick_1', 'pet_sick_2'],
      PetMood.alarmed => ['pet_alarm_1'],
    };
    setState(() {
      _bubble = tr(lines[Random().nextInt(lines.length)], {'pet': app.petName});
      _tipIndex = (_tipIndex + 1) % 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final unlockedId = app.lastUnlocked;
    if (unlockedId != null) {
      app.lastUnlocked = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final a = achievements.firstWhere((x) => x.id == unlockedId);
        showSnack(context, '${a.emoji}  ${tr('ach_unlocked')}: ${tr(a.id)}  +${a.reward} 🪙', color: const Color(0xFF6A5CFF));
      });
    }
    final health = app.health;
    final healthColor = health >= 80
        ? safeGreen
        : health >= 55
            ? brandBlue
            : health >= 30
                ? warnAmber
                : dangerRed;
    final moodText = switch (app.mood) {
      PetMood.happy => tr('mood_happy', {'pet': app.petName}),
      PetMood.ok => tr('mood_ok', {'pet': app.petName}),
      PetMood.worried => tr('mood_worried', {'pet': app.petName}),
      PetMood.sick => tr('mood_sick', {'pet': app.petName}),
      PetMood.alarmed => tr('mood_alarmed', {'pet': app.petName}),
    };

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: app.refreshDevice,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ShieldPal', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      Text(tr('level_x', {'x': app.level}) + (app.streak > 0 ? '  ·  🔥 ${app.streak}' : ''),
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                CoinBadge(coins: app.coins),
              ],
            ),
            const SizedBox(height: 12),
            // ---------------- Pet card ----------------
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [healthColor.withValues(alpha: 0.25), theme.cardTheme.color ?? theme.colorScheme.surface],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      key: ValueKey(_bubble ?? moodText),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
                      ),
                      child: Text(_bubble ?? moodText, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  PetView(mood: app.mood, look: app.look, size: 230, onTap: () => _petTapped(app)),
                  Text(app.petName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('❤️'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: health / 100),
                            duration: const Duration(milliseconds: 900),
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 14,
                              color: healthColor,
                              backgroundColor: healthColor.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$health%', style: TextStyle(fontWeight: FontWeight.w900, color: healthColor)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GradientButton(
                    label: tr('scan_phone'),
                    icon: Icons.radar_rounded,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
                  ),
                  if (app.lastAuditTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(tr('last_scan', {'x': _ago(app.lastAuditTime!)}), style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (!app.checkedInToday)
              Card(
                color: const Color(0xFFFFF3C4),
                child: ListTile(
                  leading: const Text('🎁', style: TextStyle(fontSize: 28)),
                  title: Text(tr('daily_reward'), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5B3B00))),
                  subtitle: Text(tr('daily_reward_sub'), style: const TextStyle(color: Color(0xFF7A5200))),
                  trailing: FilledButton(
                    onPressed: () {
                      final r = app.dailyCheckIn();
                      if (r > 0) showSnack(context, tr('daily_got', {'x': r, 'd': app.streak}));
                    },
                    child: Text(tr('claim')),
                  ),
                ),
              ),
            // ---------------- Protection status ----------------
            SectionCard(
              title: tr('protection'),
              icon: Icons.shield_moon_rounded,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(context, '👁️', tr('live_guard'), app.liveGuard, DeviceBridge.isAndroid),
                  _chip(context, '🌐', tr('shield_vpn'), app.vpnOn, DeviceBridge.isAndroid),
                  _chip(context, '🔒', tr('app_lock'), app.appLock, true),
                  _chip(context, '🔐', tr('two_fa'), app.totp.isNotEmpty, true),
                ],
              ),
            ),
            // ---------------- Quick tools ----------------
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                ToolTile(
                  emoji: '🔗',
                  title: tr('tool_link'),
                  subtitle: tr('tool_link_sub'),
                  colors: const [Color(0xFF6A5CFF), Color(0xFF3A8DFF)],
                  onTap: () => _go(const LinkCheckScreen()),
                ),
                ToolTile(
                  emoji: '💬',
                  title: tr('tool_msg'),
                  subtitle: tr('tool_msg_sub'),
                  colors: const [Color(0xFFFF6B8B), Color(0xFFFF9A5A)],
                  onTap: () => _go(const MessageCheckScreen()),
                ),
                ToolTile(
                  emoji: '📷',
                  title: tr('tool_qr'),
                  subtitle: tr('tool_qr_sub'),
                  colors: const [Color(0xFF00C389), Color(0xFF34C6E0)],
                  onTap: () => _go(const QrScanScreen()),
                ),
                ToolTile(
                  emoji: '📞',
                  title: tr('tool_number'),
                  subtitle: tr('tool_number_sub'),
                  colors: const [Color(0xFFFFA62B), Color(0xFFFF6B3D)],
                  onTap: () => _go(const NumberCheckScreen()),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ---------------- Threats ----------------
            SectionCard(
              title: tr('recent_threats'),
              icon: Icons.bug_report_rounded,
              child: app.threats.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(tr('no_threats', {'pet': app.petName})),
                    )
                  : Column(
                      children: [
                        for (final t in app.threats.take(3)) ThreatTile(threat: t),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(onPressed: () => _go(const ThreatsScreen()), child: Text(tr('see_all'))),
                        ),
                      ],
                    ),
            ),
            // ---------------- Tip ----------------
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _go(const TipsScreen()),
              child: SectionCard(
                title: tr('tip_title'),
                icon: Icons.lightbulb_rounded,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Tips.tipOfDay()),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (!app.tipReadToday) Text('+2 🪙  ', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(tr('see_tips'), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ]),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String emoji, String label, bool on, bool available) {
    return ActionChip(
      avatar: Text(emoji),
      label: Text('$label · ${available ? (on ? tr('on') : tr('off')) : tr('n_a')}'),
      side: BorderSide(color: on ? safeGreen : Colors.grey.withValues(alpha: 0.4), width: on ? 2 : 1),
      onPressed: () => _go(const ProtectionScreen()),
    );
  }

  void _go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return tr('just_now');
    if (d.inHours < 1) return tr('min_ago', {'x': d.inMinutes});
    if (d.inDays < 1) return tr('hours_ago', {'x': d.inHours});
    return tr('days_ago', {'x': d.inDays});
  }
}
