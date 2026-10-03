import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:provider/provider.dart';

import '../core/device_bridge.dart';
import '../core/phone_lookup.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class NumberCheckScreen extends StatefulWidget {
  const NumberCheckScreen({super.key});

  @override
  State<NumberCheckScreen> createState() => _NumberCheckScreenState();
}

class _NumberCheckScreenState extends State<NumberCheckScreen> {
  final _c = TextEditingController();
  NumberReport? _r;
  String? _contact; // name saved in the user's own contacts
  bool _contactsOk = false;

  IsoCode _home(AppState app) =>
      IsoCode.values.firstWhere((e) => e.name == app.homeCountry, orElse: () => IsoCode.PK);

  Future<void> _check() async {
    final app = context.read<AppState>();
    FocusScope.of(context).unfocus();
    final r = PhoneLookup.check(_c.text, home: _home(app), reported: app.reportedNumbers);
    setState(() {
      _r = r;
      _contact = null;
    });
    app.addCoins(1);
    if (DeviceBridge.isAndroid && r.international != null) {
      final ok = await DeviceBridge.instance.contactsAllowed();
      final name = ok ? await DeviceBridge.instance.contactName(r.international!) : null;
      if (mounted) {
        setState(() {
          _contactsOk = ok;
          _contact = name;
        });
      }
    }
  }

  Future<void> _allowContacts() async {
    final ok = await DeviceBridge.instance.requestContacts();
    if (!mounted) return;
    setState(() => _contactsOk = ok);
    if (ok) await _check();
  }

  Future<void> _web(String url) => DeviceBridge.instance.openLink(Uri.parse(url));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: Text(tr('tool_number'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr('number_intro')),
        const SizedBox(height: 12),
        Row(children: [
          DropdownButton<String>(
            value: app.homeCountry,
            underline: const SizedBox(),
            items: [
              for (final iso in const ['PK', 'IN', 'BD', 'AE', 'SA', 'GB', 'US', 'CA', 'TR', 'ID', 'MY', 'EG', 'NG', 'BR', 'MX', 'ES', 'FR', 'DE', 'RU', 'CN', 'AF', 'QA', 'KW', 'OM'])
                DropdownMenuItem(value: iso, child: Text('${PhoneLookup.flag(iso)} $iso')),
            ],
            onChanged: (v) => app.update((s) => s.homeCountry = v ?? 'PK'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _c,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '+92 300 1234567', prefixIcon: Icon(Icons.phone_rounded)),
              onSubmitted: (_) => _check(),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        GradientButton(label: tr('check_number'), icon: Icons.manage_search_rounded, onPressed: _check),
        const SizedBox(height: 16),
        if (r != null) ...[
          VerdictBanner(
            verdict: verdictForScore(r.risk),
            score: r.risk,
            subtitle: r.reportedByYou ? tr('why_reported') : (r.warnings.isEmpty ? tr('why_clean') : tr('why_flags', {'x': r.warnings.length})),
          ),
          SectionCard(
            title: tr('number_info'),
            icon: Icons.info_rounded,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.international != null) _row(tr('nd_number'), r.international!),
              if (r.countryIso != null) _row(tr('nd_country'), '${PhoneLookup.flag(r.countryIso!)} ${r.countryIso} (+${r.countryCode})'),
              _row(tr('nd_type'), r.type == null ? tr('unknown') : tr(r.type!)),
              if (r.network != null) _row(tr('nd_network'), '${r.network} ${tr('nd_network_note')}'),
              _row(tr('nd_valid'), r.valid ? tr('yes') : tr('no')),
              _row(tr('nd_owner'), _contact ?? tr('nd_owner_none')),
            ]),
          ),
          if (DeviceBridge.isAndroid && !_contactsOk)
            Card(
              color: brandBlue.withValues(alpha: 0.1),
              child: ListTile(
                leading: const Icon(Icons.contacts_rounded, color: brandBlue),
                title: Text(tr('contacts_ask_title')),
                subtitle: Text(tr('contacts_ask_body')),
                trailing: TextButton(onPressed: _allowContacts, child: Text(tr('allow'))),
              ),
            ),
          if (r.warnings.isNotEmpty)
            SectionCard(
              title: tr('red_flags'),
              icon: Icons.flag_rounded,
              child: Column(children: [for (final w in r.warnings) FindingTile(code: w, weight: w == 'w_short_code' ? 5 : 30)]),
            ),
          SectionCard(
            title: tr('who_is_it'),
            icon: Icons.privacy_tip_rounded,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('who_is_it_body')),
              if (r.international != null) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  ActionChip(
                    avatar: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Google'),
                    onPressed: () => _web('https://www.google.com/search?q=%22${Uri.encodeComponent(r.international!)}%22'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.person_search_rounded, size: 18),
                    label: const Text('Truecaller'),
                    onPressed: () => _web('https://www.truecaller.com/search/${(r.countryIso ?? 'pk').toLowerCase()}/${r.international!.replaceAll('+', '').substring((r.countryCode ?? '').length)}'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Sync.me'),
                    onPressed: () => _web('https://sync.me/search/?number=${Uri.encodeComponent(r.international!)}'),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(tr('lookup_note'), style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          ),
          if (r.international != null && r.reportedByYou)
            OutlinedButton.icon(
              icon: const Icon(Icons.undo_rounded),
              label: Text(tr('unreport_number')),
              onPressed: () {
                app.unreportNumber(r.international!);
                _check();
              },
            ),
          if (r.international != null && !r.reportedByYou)
            OutlinedButton.icon(
              icon: const Icon(Icons.report_rounded, color: dangerRed),
              label: Text(tr('report_scam_number')),
              onPressed: () {
                app.reportNumber(r.international!);
                _check();
                showSnack(context, tr('reported'));
              },
            ),
        ],
      ]),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ]),
      );
}
