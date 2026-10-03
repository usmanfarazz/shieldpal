import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/assistant.dart';
import '../core/device_bridge.dart';
import '../core/link_scanner.dart';
import '../core/secure_store.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Settings → Online services & AI. Explains every optional online service in
/// plain words (what it does, what is sent, whether a key is needed) and lets
/// the user switch each on/off and TEST that it really works.
class OnlineServicesScreen extends StatefulWidget {
  const OnlineServicesScreen({super.key});

  @override
  State<OnlineServicesScreen> createState() => _OnlineServicesScreenState();
}

class _OnlineServicesScreenState extends State<OnlineServicesScreen> {
  final _claude = TextEditingController();
  final _google = TextEditingController();
  final _urlscan = TextEditingController();
  final Map<String, String> _result = {}; // service -> test message
  final Set<String> _busy = {};
  bool _show = false;

  @override
  void initState() {
    super.initState();
    () async {
      _claude.text = await SecureStore.instance.read(SecureStore.claudeKey) ?? '';
      _google.text = await SecureStore.instance.read(SecureStore.safeBrowsingKey) ?? '';
      _urlscan.text = await SecureStore.instance.read(SecureStore.urlscanKey) ?? '';
      if (mounted) setState(() {});
    }();
  }

  Future<void> _saveKeys() async {
    await SecureStore.instance.write(SecureStore.claudeKey, _claude.text.trim());
    await SecureStore.instance.write(SecureStore.safeBrowsingKey, _google.text.trim());
    await SecureStore.instance.write(SecureStore.urlscanKey, _urlscan.text.trim());
    if (!mounted) return;
    final app = context.read<AppState>();
    if (_claude.text.trim().isNotEmpty && !app.assistantOnline) {
      app.update((s) => s.assistantOnline = true);
    } else if (_claude.text.trim().isEmpty && app.assistantOnline) {
      app.update((s) => s.assistantOnline = false);
    } else {
      app.update((_) {}); // pushes the new Safe Browsing key to the background service
    }
  }

  Future<void> _test(String id) async {
    setState(() {
      _busy.add(id);
      _result.remove(id);
    });
    String msg;
    final app = context.read<AppState>();
    try {
      await _saveKeys();
      switch (id) {
        case 'free':
          final r = await Assistant.freeOnline([ChatMessage(true, 'Reply with just: OK')], app.petName, 'English');
          msg = r == null ? '❌ ${tr('svc_test_fail')}' : '✅ ${tr('svc_test_ok')}';
        case 'claude':
          final r = await Assistant.online([ChatMessage(true, 'Reply with just: OK')], app.petName, 'English');
          msg = r == null ? '❌ ${tr('svc_need_key')}' : '✅ ${tr('svc_test_ok')}';
        case 'cloud':
          final r = await LinkScanner.cloudflareCheck('https://malware.testcategory.com/');
          msg = r == true ? '✅ ${tr('svc_test_ok')}' : (r == false ? '⚠️ ${tr('svc_test_nodetect')}' : '❌ ${tr('svc_test_fail')}');
        case 'google':
          if (_google.text.trim().isEmpty) {
            msg = '❌ ${tr('svc_need_key')}';
          } else {
            final (flag, _) = await LinkScanner.googleCheck('http://testsafebrowsing.appspot.com/s/malware.html');
            msg = flag == null ? '❌ ${tr('svc_test_badkey')}' : '✅ ${tr('svc_test_ok')}';
          }
        case 'urlscan':
          if (_urlscan.text.trim().isEmpty) {
            msg = '❌ ${tr('svc_need_key')}';
          } else {
            final r = await http
                .get(Uri.parse('https://urlscan.io/user/quotas/'), headers: {'API-Key': _urlscan.text.trim()})
                .timeout(const Duration(seconds: 12));
            msg = r.statusCode == 200 ? '✅ ${tr('svc_test_ok')}' : '❌ ${tr('svc_test_badkey')} (${r.statusCode})';
          }
        default:
          msg = '';
      }
    } catch (e) {
      msg = '❌ ${tr('svc_test_fail')}';
    }
    if (!mounted) return;
    setState(() {
      _busy.remove(id);
      _result[id] = msg;
    });
  }

  Future<void> _open(String url) => DeviceBridge.instance.openInBrowser(Uri.parse(url));

  Widget _status(bool? on, {bool needsKey = false}) {
    final (text, color) = on == true
        ? (tr('on'), safeGreen)
        : needsKey
            ? (tr('svc_needs_key'), warnAmber)
            : (tr('off'), Colors.grey);
    return Chip(
      label: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      backgroundColor: color.withValues(alpha: 0.14),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _card({
    required String emoji,
    required String title,
    required Widget status,
    required String what,
    required String sent,
    required String id,
    List<Widget> children = const [],
    bool testable = true,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            status,
          ]),
          const SizedBox(height: 6),
          Text(what),
          const SizedBox(height: 6),
          Text('🔎 ${tr('svc_sent')}: $sent', style: theme.textTheme.bodySmall),
          ...children,
          if (testable) ...[
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _busy.contains(id) ? null : () => _test(id),
                icon: _busy.contains(id)
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bolt_rounded),
                label: Text(tr('svc_test')),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_result[id] ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _keyField(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          controller: c,
          obscureText: !_show,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: IconButton(
              icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('online_services'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Card(
          color: brandBlue.withValues(alpha: 0.1),
          child: Padding(padding: const EdgeInsets.all(14), child: Text(tr('svc_intro'))),
        ),
        // ---- Free AI ----
        _card(
          id: 'free',
          emoji: '✨',
          title: tr('svc_free_ai'),
          status: _status(app.freeAi == 1),
          what: tr('svc_free_ai_what'),
          sent: tr('svc_free_ai_sent'),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('svc_free_ai_switch')),
              value: app.freeAi == 1,
              onChanged: (v) => app.update((s) => s.freeAi = v ? 1 : 2),
            ),
          ],
        ),
        // ---- Claude ----
        _card(
          id: 'claude',
          emoji: '🧠',
          title: 'Claude (Anthropic)',
          status: _status(app.assistantOnline && _claude.text.trim().isNotEmpty, needsKey: _claude.text.trim().isEmpty),
          what: tr('svc_claude_what'),
          sent: tr('svc_claude_sent'),
          children: [
            _keyField('Claude API key', _claude),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('ai_use_online')),
              value: app.assistantOnline,
              onChanged: (v) => app.update((s) => s.assistantOnline = v),
            ),
            TextButton.icon(
              onPressed: () => _open('https://console.anthropic.com/settings/keys'),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(tr('svc_get_key')),
            ),
          ],
        ),
        // ---- Cloudflare (no key) ----
        _card(
          id: 'cloud',
          emoji: '☁️',
          title: tr('cloud_check_title'),
          status: _status(app.cloudCheck),
          what: tr('svc_cloud_what'),
          sent: tr('svc_cloud_sent'),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('svc_cloud_switch')),
              value: app.cloudCheck,
              onChanged: (v) => app.update((s) => s.cloudCheck = v),
            ),
          ],
        ),
        // ---- Google Safe Browsing ----
        _card(
          id: 'google',
          emoji: '🛡️',
          title: 'Google Safe Browsing',
          status: _status(_google.text.trim().isNotEmpty, needsKey: _google.text.trim().isEmpty),
          what: tr('svc_google_what'),
          sent: tr('svc_google_sent'),
          children: [
            _keyField('Safe Browsing API key', _google),
            const SizedBox(height: 4),
            Text(tr('svc_google_steps'), style: Theme.of(context).textTheme.bodySmall),
            TextButton.icon(
              onPressed: () => _open('https://console.cloud.google.com/apis/library/safebrowsing.googleapis.com'),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(tr('svc_get_key')),
            ),
          ],
        ),
        // ---- urlscan ----
        _card(
          id: 'urlscan',
          emoji: '🔬',
          title: 'urlscan.io',
          status: _status(_urlscan.text.trim().isNotEmpty, needsKey: _urlscan.text.trim().isEmpty),
          what: tr('svc_urlscan_what'),
          sent: tr('svc_urlscan_sent'),
          children: [
            _keyField('urlscan.io API key', _urlscan),
            TextButton.icon(
              onPressed: () => _open('https://urlscan.io/user/signup'),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(tr('svc_get_key')),
            ),
          ],
        ),
        // ---- HIBP (info) ----
        _card(
          id: 'hibp',
          emoji: '🔑',
          title: 'Have I Been Pwned',
          status: _status(true),
          what: tr('svc_hibp_what'),
          sent: tr('svc_hibp_sent'),
          testable: false,
        ),
        const SizedBox(height: 8),
        GradientButton(
          label: tr('save'),
          icon: Icons.save_rounded,
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final saved = tr('saved');
            await _saveKeys();
            messenger.showSnackBar(SnackBar(content: Text(saved)));
          },
        ),
      ]),
    );
  }
}
