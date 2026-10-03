import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/device_bridge.dart';
import '../core/secure_store.dart';
import '../core/vpn_servers.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});

  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen> with WidgetsBindingObserver {
  bool _notifAllowed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await context.read<AppState>().refreshDevice();
    final n = await DeviceBridge.instance.notificationsAllowed();
    if (mounted) setState(() => _notifAllowed = n);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final android = DeviceBridge.isAndroid;
    return Scaffold(
      appBar: AppBar(title: Text(tr('protection'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // -------- Live Guard --------
        _bigCard(
          context,
          emoji: '👁️',
          title: tr('live_guard'),
          on: app.liveGuard,
          body: tr('live_guard_body'),
          available: android,
          action: android
              ? FilledButton(
                  onPressed: DeviceBridge.instance.openLiveGuardSettings,
                  child: Text(app.liveGuard ? tr('manage') : tr('turn_on')),
                )
              : null,
        ),
        if (android && !_notifAllowed)
          Card(
            color: warnAmber.withValues(alpha: 0.15),
            child: ListTile(
              leading: const Icon(Icons.notifications_off_rounded, color: warnAmber),
              title: Text(tr('allow_notifs')),
              trailing: TextButton(
                onPressed: () async {
                  await DeviceBridge.instance.requestNotifications();
                  _refresh();
                },
                child: Text(tr('allow')),
              ),
            ),
          ),
        SectionCard(
          title: tr('alerts'),
          icon: Icons.campaign_rounded,
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: app.voiceAlerts,
              onChanged: (v) => app.update((s) => s.voiceAlerts = v),
              title: Text(tr('voice_alerts')),
              subtitle: Text(tr('voice_alerts_sub', {'pet': app.petName})),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: app.alarmSound,
              onChanged: (v) => app.update((s) => s.alarmSound = v),
              title: Text(tr('alarm_sound')),
              subtitle: Text(tr('alarm_sound_sub')),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(tr('test_alert')),
                onPressed: () {
                  app.alarm();
                  app.say(tr('speak_link', {'pet': app.petName}));
                },
              ),
            ),
          ]),
        ),
        // -------- Shield VPN --------
        _bigCard(
          context,
          emoji: '🌐',
          title: tr('shield_vpn'),
          on: app.vpnOn,
          body: '${tr('vpn_body')}${app.vpnOn ? '\n\n${tr('vpn_blocked', {'x': app.vpnBlocked})}' : ''}',
          available: android,
          action: android
              ? FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: app.vpnOn ? dangerRed : null),
                  onPressed: () async {
                    if (app.vpnOn) {
                      await DeviceBridge.instance.stopVpn();
                    } else {
                      final ok = await DeviceBridge.instance.startVpn();
                      if (!ok && context.mounted) showSnack(context, tr('vpn_permission'));
                    }
                    await Future<void>.delayed(const Duration(milliseconds: 600));
                    _refresh();
                  },
                  child: Text(app.vpnOn ? tr('turn_off') : tr('turn_on')),
                )
              : null,
        ),
        if (android) _VpnServerCard(onChanged: _refresh),
        if (android) _RemoteVpnCard(onChanged: _refresh),
        // -------- Safe link gate --------
        _bigCard(
          context,
          emoji: '🚧',
          title: tr('link_gate'),
          on: null,
          body: tr('link_gate_body'),
          available: android,
          action: android
              ? FilledButton.tonal(onPressed: () => DeviceBridge.instance.runFix('default_apps'), child: Text(tr('set_up')))
              : null,
        ),
        if (!android)
          SectionCard(
            title: tr('other_platform'),
            icon: Icons.devices_rounded,
            child: Text(tr('other_platform_body')),
          ),
      ]),
    );
  }

  Widget _bigCard(BuildContext context,
      {required String emoji,
      required String title,
      required bool? on,
      required String body,
      required bool available,
      Widget? action}) {
    final color = on == true ? safeGreen : on == false ? warnAmber : brandBlue;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: available ? color.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            if (on != null)
              Chip(
                label: Text(available ? (on ? tr('on') : tr('off')) : tr('n_a')),
                backgroundColor: (available ? color : Colors.grey).withValues(alpha: 0.15),
              ),
          ]),
          const SizedBox(height: 8),
          Text(available ? body : '$body\n\n${tr('android_only')}'),
          if (action != null) ...[const SizedBox(height: 12), action],
        ]),
      ),
    );
  }
}

/// Pick the DNS server Shield VPN uses + a one-tap test that proves the
/// internet still works through the VPN and that dangerous sites are blocked.
class _VpnServerCard extends StatefulWidget {
  final Future<void> Function() onChanged;
  const _VpnServerCard({required this.onChanged});

  @override
  State<_VpnServerCard> createState() => _VpnServerCardState();
}

class _VpnServerCardState extends State<_VpnServerCard> {
  bool _testing = false;
  List<(String, bool, String)>? _results;

  Future<void> _pick(AppState app) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(tr('vpn_server'), style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          ),
          for (final s in vpnServers)
            ListTile(
              leading: Text(s.emoji, style: const TextStyle(fontSize: 26)),
              title: Text(tr(s.nameKey)),
              subtitle: Text('${tr(s.descKey)}  ·  ${s.ip}'),
              trailing: app.vpnDns == s.id ? const Icon(Icons.check_circle_rounded, color: safeGreen) : null,
              onTap: () => Navigator.pop(c, s.id),
            ),
        ]),
      ),
    );
    if (id == null || id == app.vpnDns) return;
    app.update((s) => s.vpnDns = id);
    if (app.vpnOn) {
      // Restart so the new server is used right away (permission is already granted).
      await DeviceBridge.instance.stopVpn();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await DeviceBridge.instance.startVpn();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await widget.onChanged();
    }
    if (mounted) showSnack(context, tr('vpn_server_set', {'x': tr(vpnServerFor(id).nameKey)}));
  }

  Future<(bool, String)> _fetch(String url, {bool expectBlocked = false}) async {
    final sw = Stopwatch()..start();
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      sw.stop();
      return (!expectBlocked, '${r.statusCode} · ${sw.elapsedMilliseconds} ms');
    } on TimeoutException {
      return (false, tr('vpn_test_timeout'));
    } catch (_) {
      return (expectBlocked, expectBlocked ? tr('vpn_test_blocked') : tr('vpn_test_failed'));
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _results = null;
    });
    final app = context.read<AppState>();
    final out = <(String, bool, String)>[];
    for (final h in const ['https://www.google.com/generate_204', 'https://www.wikipedia.org/', 'https://example.com/']) {
      final r = await _fetch(h);
      out.add((Uri.parse(h).host, r.$1, r.$2));
    }
    if (app.vpnDns == 'cf_security' || app.vpnDns == 'cf_family' || app.vpnDns == 'quad9') {
      final b = await _fetch('https://malware.testcategory.com/', expectBlocked: true);
      out.add((tr('vpn_test_malware'), b.$1, b.$2));
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _results = out;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final srv = vpnServerFor(app.vpnDns);
    return SectionCard(
      title: tr('vpn_server'),
      icon: Icons.dns_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Text(srv.emoji, style: const TextStyle(fontSize: 28)),
          title: Text(tr(srv.nameKey), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${tr(srv.descKey)}  ·  ${srv.ip}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _pick(app),
        ),
        Text(tr('vpn_honest'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _testing ? null : _test,
          icon: _testing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.speed_rounded),
          label: Text(tr(app.vpnOn ? 'vpn_test' : 'vpn_test_off')),
        ),
        if (_results != null) ...[
          const SizedBox(height: 8),
          for (final r in _results!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Text(r.$2 ? '✅' : '❌'),
                const SizedBox(width: 8),
                Expanded(child: Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(r.$3, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
        ],
      ]),
    );
  }
}

/// Remote VPN: runs the user's own WireGuard config so ALL traffic leaves from
/// another server/country (opens sites that the local provider blocks).
class _RemoteVpnCard extends StatefulWidget {
  final Future<void> Function() onChanged;
  const _RemoteVpnCard({required this.onChanged});

  @override
  State<_RemoteVpnCard> createState() => _RemoteVpnCardState();
}

class _RemoteVpnCardState extends State<_RemoteVpnCard> {
  String? _config;
  bool _busy = false;
  String? _msg;
  String? _ipInfo;

  @override
  void initState() {
    super.initState();
    SecureStore.instance.read(SecureStore.wgConfig).then((v) {
      if (mounted) setState(() => _config = (v ?? '').isEmpty ? null : v);
    });
  }

  String _line(String key) {
    final c = _config ?? '';
    final m = RegExp(r'^\s*' + key + r'\s*=\s*(.+)$', multiLine: true, caseSensitive: false).firstMatch(c);
    return m?.group(1)?.trim() ?? '';
  }

  Future<void> _paste() async {
    final c = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if ((clip?.text ?? '').contains('[Interface]')) c.text = clip!.text!;
    if (!mounted) return;
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('wg_paste')),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('wg_howto'), style: Theme.of(d).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: c,
              minLines: 6,
              maxLines: 10,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(hintText: '[Interface]\nPrivateKey = ...\n\n[Peer]\nPublicKey = ...\nEndpoint = ...'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, c.text), child: Text(tr('save'))),
        ],
      ),
    );
    if (v == null) return;
    final t = v.trim();
    if (!t.contains('[Interface]') || !t.contains('[Peer]') || !t.toLowerCase().contains('privatekey')) {
      setState(() => _msg = '❌ ${tr('wg_bad_config')}');
      return;
    }
    await SecureStore.instance.write(SecureStore.wgConfig, t);
    if (mounted) {
      setState(() {
        _config = t;
        _msg = null;
      });
    }
  }

  Future<void> _toggle(AppState app) async {
    setState(() {
      _busy = true;
      _msg = null;
      _ipInfo = null;
    });
    if (app.wgOn) {
      await DeviceBridge.instance.wgStop();
    } else if (_config != null) {
      final err = await DeviceBridge.instance.wgStart(_config!);
      if (err != null && mounted) {
        setState(() => _msg = err == 'permission' ? '❌ ${tr('vpn_permission')}' : '❌ ${tr('wg_error')}: $err');
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await widget.onChanged();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _checkIp() async {
    setState(() => _ipInfo = '…');
    try {
      final r = await http.get(Uri.parse('https://ipwho.is/')).timeout(const Duration(seconds: 12));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (mounted) setState(() => _ipInfo = '${j['ip']} · ${j['country'] ?? ''} ${j['flag']?['emoji'] ?? ''}');
    } catch (_) {
      if (mounted) setState(() => _ipInfo = '❌ ${tr('vpn_test_failed')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final endpoint = _line('Endpoint');
    return SectionCard(
      title: tr('wg_title'),
      icon: Icons.public_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(tr('wg_intro'))),
          const SizedBox(width: 8),
          Chip(
            label: Text(app.wgOn ? tr('on') : tr('off')),
            backgroundColor: (app.wgOn ? safeGreen : Colors.grey).withValues(alpha: 0.15),
          ),
        ]),
        const SizedBox(height: 10),
        if (_config == null) ...[
          Text(tr('wg_howto'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste_rounded), label: Text(tr('wg_paste'))),
        ] else ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dns_rounded),
            title: Text(endpoint.isEmpty ? tr('wg_saved') : endpoint, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(tr('wg_saved')),
            trailing: IconButton(
              tooltip: tr('wg_remove'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _busy
                  ? null
                  : () async {
                      if (app.wgOn) await DeviceBridge.instance.wgStop();
                      await SecureStore.instance.write(SecureStore.wgConfig, null);
                      await widget.onChanged();
                      if (mounted) setState(() => _config = null);
                    },
            ),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: app.wgOn ? dangerRed : null),
              onPressed: _busy ? null : () => _toggle(app),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(app.wgOn ? tr('wg_disconnect') : tr('wg_connect')),
            ),
            OutlinedButton.icon(onPressed: _checkIp, icon: const Icon(Icons.my_location_rounded), label: Text(tr('wg_check_ip'))),
          ]),
        ],
        if (app.wgOn) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('wg_shield_off'), style: Theme.of(context).textTheme.bodySmall)),
        if (_ipInfo != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${tr('wg_your_ip')}: $_ipInfo', style: const TextStyle(fontWeight: FontWeight.w800))),
        if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!)),
      ]),
    );
  }
}
