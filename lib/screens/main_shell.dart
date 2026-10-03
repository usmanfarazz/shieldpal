import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/url_analyzer.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'assistant_screen.dart';
import 'home_screen.dart';
import 'link_check_screen.dart';
import 'message_check_screen.dart';
import 'play_screen.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';
import 'vault_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  final Set<int> _visited = {0}; // tabs are built lazily, so the app opens fast
  DateTime? _lastBack;

  /// Back goes to the Home tab first; from Home a second quick Back exits.
  /// (Before, Back on any tab closed the whole app.)
  void _onBack() {
    if (_tab != 0) {
      setState(() => _tab = 0);
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    showSnack(context, tr('back_again'));
  }

  /// Text or links shared to ShieldPal from WhatsApp / browser / any app.
  void _handleShared(AppState app) {
    final shared = app.pendingShared;
    if (shared == null || shared.isEmpty) return;
    app.pendingShared = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // "gate:" = a link the user tapped in another app (Safe Link Gate).
      if (shared.startsWith('gate:')) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LinkCheckScreen(initial: shared.substring(5), autoStart: true, openIfSafe: true),
        ));
        return;
      }
      final urls = UrlAnalyzer.extractUrls(shared);
      final onlyLink = urls.length == 1 && urls.first.length >= shared.trim().length - 2;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => onlyLink ? LinkCheckScreen(initial: urls.first, autoStart: true) : MessageCheckScreen(initial: shared),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    _handleShared(context.watch<AppState>());
    final builders = <Widget Function()>[
      () => const HomeScreen(),
      () => const ToolsScreen(),
      () => const PlayScreen(),
      () => const VaultScreen(),
      () => const SettingsScreen(),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [for (var i = 0; i < builders.length; i++) _visited.contains(i) ? builders[i]() : const SizedBox.shrink()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'pal_ai',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
        icon: const Text('✨', style: TextStyle(fontSize: 20)),
        label: Text(tr('ask_ai')),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _visited.add(i);
        }),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.pets_outlined), selectedIcon: const Icon(Icons.pets), label: tr('tab_home')),
          NavigationDestination(icon: const Icon(Icons.shield_outlined), selectedIcon: const Icon(Icons.shield), label: tr('tab_tools')),
          NavigationDestination(icon: const Icon(Icons.sports_esports_outlined), selectedIcon: const Icon(Icons.sports_esports), label: tr('tab_play')),
          NavigationDestination(icon: const Icon(Icons.key_outlined), selectedIcon: const Icon(Icons.key), label: tr('tab_vault')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: tr('tab_settings')),
        ],
      ),
    ),
    );
  }
}
