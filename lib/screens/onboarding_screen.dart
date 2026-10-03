import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/device_bridge.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pet_view.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  final _name = TextEditingController(text: 'Pip');
  int _i = 0;

  void _next() {
    if (_i < 2) {
      _page.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      context.read<AppState>().finishOnboarding(_name.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: brandGradient),
        child: SafeArea(
          child: Column(children: [
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _i = i),
                children: [
                  _page1(context, app),
                  _page2(context, app),
                  _page3(context, app),
                ],
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 3; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: i == _i ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == _i ? 1 : 0.5), borderRadius: BorderRadius.circular(4)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: brandBlue),
                  onPressed: _next,
                  child: Text(_i < 2 ? tr('next') : tr('lets_go'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  TextStyle get _h => const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900);
  TextStyle get _p => const TextStyle(color: Colors.white, fontSize: 16);

  Widget _page1(BuildContext context, AppState app) => ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 20),
        const Center(child: PetView(mood: PetMood.happy, size: 200)),
        Text('ShieldPal', textAlign: TextAlign.center, style: _h.copyWith(fontSize: 40)),
        Text(tr('onb_tagline'), textAlign: TextAlign.center, style: _p),
        const SizedBox(height: 24),
        Text(tr('choose_language'), style: _p.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in appLanguages)
            ChoiceChip(
              label: Text(l.nativeName),
              selected: app.lang == l.code,
              onSelected: (_) => app.setLanguage(l.code),
            ),
        ]),
      ]);

  Widget _page2(BuildContext context, AppState app) => ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 20),
        Center(
          child: PetView(
            mood: PetMood.happy,
            size: 220,
            onTap: () => app.say(tr('pet_hello', {'pet': _name.text})),
          ),
        ),
        Text(tr('onb_meet'), textAlign: TextAlign.center, style: _h),
        const SizedBox(height: 8),
        Text(tr('onb_meet_body'), textAlign: TextAlign.center, style: _p),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          maxLength: 16,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: InputDecoration(labelText: tr('pet_name'), fillColor: Colors.white),
        ),
      ]);

  Widget _page3(BuildContext context, AppState app) => ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 20),
        Text(tr('onb_power'), style: _h),
        const SizedBox(height: 16),
        for (final (e, k) in const [
          ('👁️', 'onb_f1'),
          ('🔗', 'onb_f2'),
          ('🛰️', 'onb_f3'),
          ('🌐', 'onb_f4'),
          ('🔐', 'onb_f5'),
          ('🎮', 'onb_f6'),
          ('✨', 'onb_f7'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(child: Text(tr(k), style: _p)),
            ]),
          ),
        const SizedBox(height: 12),
        if (DeviceBridge.isAndroid)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
            onPressed: () async {
              await DeviceBridge.instance.requestNotifications();
              await DeviceBridge.instance.openLiveGuardSettings();
            },
            icon: const Icon(Icons.visibility_rounded),
            label: Text(tr('enable_live_guard')),
          ),
        const SizedBox(height: 8),
        Text(tr('onb_privacy'), style: _p.copyWith(fontSize: 13)),
      ]);
}
