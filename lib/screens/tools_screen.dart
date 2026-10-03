import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../widgets/common.dart';
import 'family_screen.dart';
import 'link_check_screen.dart';
import 'message_check_screen.dart';
import 'number_check_screen.dart';
import 'password_screen.dart';
import 'protection_screen.dart';
import 'qr_scan_screen.dart';
import 'scan_screen.dart';
import 'threats_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final tools = <(String, String, String, List<Color>, Widget)>[
      ('🛰️', tr('deep_scan'), tr('deep_scan_sub'), const [Color(0xFF6A5CFF), Color(0xFF34C6E0)], const ScanScreen()),
      ('🔗', tr('tool_link'), tr('tool_link_sub'), const [Color(0xFF6A5CFF), Color(0xFF3A8DFF)], const LinkCheckScreen()),
      ('💬', tr('tool_msg'), tr('tool_msg_sub'), const [Color(0xFFFF6B8B), Color(0xFFFF9A5A)], const MessageCheckScreen()),
      ('📷', tr('tool_qr'), tr('tool_qr_sub'), const [Color(0xFF00C389), Color(0xFF34C6E0)], const QrScanScreen()),
      ('📞', tr('tool_number'), tr('tool_number_sub'), const [Color(0xFFFFA62B), Color(0xFFFF6B3D)], const NumberCheckScreen()),
      ('🔑', tr('tool_password'), tr('tool_password_sub'), const [Color(0xFF3D4A5C), Color(0xFF6B7A90)], const PasswordScreen()),
      ('👁️', tr('protection'), tr('protection_sub'), const [Color(0xFF16A34A), Color(0xFF65D46E)], const ProtectionScreen()),
      ('👨‍👩‍👧', tr('family_code'), tr('family_code_sub'), const [Color(0xFFC86BFA), Color(0xFFFF9AD5)], const FamilyScreen()),
      ('🚨', tr('threat_log'), tr('threat_log_sub'), const [Color(0xFFEF4444), Color(0xFFF97316)], const ThreatsScreen()),
    ];
    return SafeArea(
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('tab_tools'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              Text(tr('tools_sub')),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverGrid.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: [
              for (final t in tools) ToolTile(emoji: t.$1, title: t.$2, subtitle: t.$3, colors: t.$4, onTap: () => go(t.$5)),
            ],
          ),
        ),
      ]),
    );
  }
}
