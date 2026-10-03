import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../core/secure_store.dart';
import '../core/totp.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pet_view.dart';
import 'online_services_screen.dart';
import 'privacy_screen.dart';
import 'protection_screen.dart';
import 'voice_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    void go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Text(tr('tab_settings'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        // ---- Language ----
        Card(
          child: ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(tr('language')),
            subtitle: Text(app.language.nativeName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLanguagePicker(context),
          ),
        ),
        // ---- Pet ----
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.pets_rounded),
                const SizedBox(width: 12),
                Expanded(child: Text(tr('pet_choose'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 112,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final sp in petSpecies)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => app.update((s) => s.species = sp.$1),
                        child: Container(
                          width: 92,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: app.species == sp.$1 ? brandBlue : Colors.grey.withValues(alpha: 0.3),
                              width: app.species == sp.$1 ? 3 : 1,
                            ),
                          ),
                          child: Column(children: [
                            Expanded(
                              child: PetStatic(
                                  size: 80, look: PetLook(skin: app.skin, hat: app.hat, glasses: app.glasses, extra: app.extra, species: sp.$1)),
                            ),
                            Text(tr('species_${sp.$1}'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_rounded),
                title: Text(tr('pet_name')),
                subtitle: Text(app.petName),
                trailing: const Icon(Icons.edit_rounded, size: 20),
                onTap: () async {
                  final c = TextEditingController(text: app.petName);
                  final v = await showDialog<String>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: Text(tr('pet_name')),
                      content: TextField(controller: c, autofocus: true, maxLength: 16),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('cancel'))),
                        FilledButton(onPressed: () => Navigator.pop(d, c.text), child: Text(tr('save'))),
                      ],
                    ),
                  );
                  if (v != null && v.trim().isNotEmpty) app.update((s) => s.petName = v.trim());
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.record_voice_over_rounded),
                title: Text(tr('voice_title')),
                subtitle: Text(tr('voice_sub')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => go(const VoiceScreen()),
              ),
            ]),
          ),
        ),
        // ---- Protection / lock ----
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.shield_rounded),
              title: Text(tr('protection')),
              subtitle: Text(tr('protection_sub')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => go(const ProtectionScreen()),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.lock_rounded),
              title: Text(tr('app_lock')),
              subtitle: Text(tr('app_lock_sub')),
              value: app.appLock,
              onChanged: (v) async {
                if (v) {
                  final ok = await setPinFlow(context);
                  if (ok) app.update((s) => s.appLock = true);
                } else {
                  await SecureStore.instance.write(SecureStore.appPin, null);
                  app.update((s) => s.appLock = false);
                }
              },
            ),
            if (app.appLock)
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded),
                title: Text(tr('biometric')),
                value: app.biometric,
                onChanged: (v) => app.update((s) => s.biometric = v),
              ),
          ]),
        ),
        // ---- Online services & AI ----
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_sync_rounded),
            title: Text(tr('online_services')),
            subtitle: Text(tr('online_services_sub')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => go(const OnlineServicesScreen()),
          ),
        ),
        // ---- Privacy ----
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.privacy_tip_rounded),
              title: Text(tr('privacy_policy')),
              subtitle: Text(tr('privacy_sub')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => go(const PrivacyPolicyScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_rounded),
              title: Text(tr('data_safety')),
              subtitle: Text(tr('data_safety_sub')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => go(const DataSafetyScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: dangerRed),
              title: Text(tr('delete_all')),
              subtitle: Text(tr('delete_all_sub')),
              onTap: () => confirmAndDeleteAllData(context),
            ),
          ]),
        ),
        // ---- About ----
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.info_rounded),
              title: Text('ShieldPal $kAppVersion'),
              subtitle: Text(tr('about_sub')),
            ),
            ListTile(
              leading: const Icon(Icons.rate_review_rounded),
              title: Text(tr('send_feedback')),
              subtitle: Text(tr('send_feedback_sub')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => launchUrl(
                Uri(scheme: 'mailto', path: kContactEmail, queryParameters: {'subject': 'ShieldPal $kAppVersion feedback'}),
                mode: LaunchMode.externalApplication,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user_rounded),
              title: Text(tr('made_by', {'x': kDeveloper})),
            ),
          ]),
        ),
      ]),
    );
  }
}

Future<void> showLanguagePicker(BuildContext context) {
  final app = context.read<AppState>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.75),
        child: RadioGroup<String>(
          groupValue: app.lang,
          onChanged: (v) {
            if (v == null) return;
            app.setLanguage(v);
            Navigator.pop(c);
          },
          child: ListView(shrinkWrap: true, children: [
            for (final l in appLanguages) RadioListTile<String>(value: l.code, title: Text(l.nativeName)),
          ]),
        ),
      ),
    ),
  );
}

/// Asks for a new PIN twice. Returns true when saved.
Future<bool> setPinFlow(BuildContext context) async {
  Future<String?> ask(String title) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: InputDecoration(hintText: tr('pin_hint')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, c.text), child: Text(tr('ok'))),
        ],
      ),
    );
  }

  final a = await ask(tr('new_pin'));
  if (a == null || a.length < 4) {
    if (context.mounted && a != null) showSnack(context, tr('pin_short'));
    return false;
  }
  if (!context.mounted) return false;
  final b = await ask(tr('repeat_pin'));
  if (a != b) {
    if (context.mounted) showSnack(context, tr('pin_mismatch'));
    return false;
  }
  await SecureStore.instance.write(SecureStore.appPin, Totp.hashPin(a));
  try {
    if (!await LocalAuthentication().isDeviceSupported() && context.mounted) {
      context.read<AppState>().update((s) => s.biometric = false);
    }
  } catch (_) {}
  return true;
}
