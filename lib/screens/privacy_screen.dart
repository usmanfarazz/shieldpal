import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../core/policy_text.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Full privacy policy, written from the same source as store/privacy_policy.html.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = (L10n.current.code == 'rur' || L10n.current.code == 'ur') ? policyRur : policyEn;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('privacy_policy'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text('ShieldPal', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        Text('${tr('pp_updated')}: $policyUpdated', style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        for (var i = 0; i < sections.length; i++)
          Card(
            color: i == 0 ? safeGreen.withValues(alpha: 0.12) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sections[i].title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                SelectableText(sections[i].body),
              ]),
            ),
          ),
        if (kPrivacyUrl.isNotEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(tr('pp_web')),
            onPressed: () => launchUrl(Uri.parse(kPrivacyUrl), mode: LaunchMode.externalApplication),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.mail_rounded),
          label: Text(kContactEmail),
          onPressed: () => launchUrl(Uri.parse('mailto:$kContactEmail?subject=ShieldPal%20privacy'), mode: LaunchMode.externalApplication),
        ),
      ]),
    );
  }
}

/// Asks, then wipes everything ShieldPal stores on this phone.
Future<void> confirmAndDeleteAllData(BuildContext context) async {
  final app = context.read<AppState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: dangerRed, size: 40),
      title: Text(tr('delete_all')),
      content: Text(tr('delete_all_q')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: dangerRed),
          onPressed: () => Navigator.pop(c, true),
          child: Text(tr('delete')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await app.deleteAllData();
  if (context.mounted) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    showSnack(context, tr('delete_done'));
  }
}

/// "Data safety" at a glance, the same answers used for the Google Play form.
class DataSafetyScreen extends StatelessWidget {
  const DataSafetyScreen({super.key});

  Widget _row(BuildContext context, String emoji, String title, String body, {Color? color}) => Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: (color ?? brandBlue).withValues(alpha: 0.15), child: Text(emoji)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(body),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('data_safety'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text(tr('ds_intro')),
        const SizedBox(height: 8),
        _row(context, '🚫', tr('ds_collect_t'), tr('ds_collect_b'), color: safeGreen),
        _row(context, '📱', tr('ds_device_t'), tr('ds_device_b'), color: safeGreen),
        _row(context, '🔒', tr('ds_secure_t'), tr('ds_secure_b'), color: safeGreen),
        _row(context, '🗑️', tr('ds_delete_t'), tr('ds_delete_b'), color: safeGreen),
        _row(context, '📢', tr('ds_ads_t'), tr('ds_ads_b'), color: safeGreen),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Text(tr('ds_optional_title'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ),
        _row(context, '🔗', tr('ds_link_t'), tr('ds_link_b'), color: warnAmber),
        _row(context, '🔑', tr('ds_pw_t'), tr('ds_pw_b'), color: warnAmber),
        _row(context, '✨', tr('ds_ai_t'), tr('ds_ai_b'), color: warnAmber),
        _row(context, '🌐', tr('ds_vpn_t'), tr('ds_vpn_b'), color: warnAmber),
        const SizedBox(height: 8),
        Card(
          color: dangerRed.withValues(alpha: 0.08),
          child: ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: dangerRed),
            title: Text(tr('delete_all'), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(tr('delete_all_sub')),
            onTap: () => confirmAndDeleteAllData(context),
          ),
        ),
      ]),
    );
  }
}
