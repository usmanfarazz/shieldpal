import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Choose how the pet speaks: voice, tone (girl / boy / cute) and speed.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final FlutterTts _tts = FlutterTts();
  List<Map<String, String>> _voices = [];
  bool _loading = true;

  static const _presets = [
    ('voice_p_girl', '👧', 1.45, 0.5),
    ('voice_p_cute', '🐾', 1.8, 0.55),
    ('voice_p_normal', '🙂', 1.0, 0.48),
    ('voice_p_boy', '👦', 0.8, 0.48),
    ('voice_p_deep', '🧔', 0.55, 0.42),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final lang = context.read<AppState>().language.ttsLocale.split('-').first.toLowerCase();
    try {
      final raw = await _tts.getVoices as List?;
      final list = <Map<String, String>>[];
      for (final v in raw ?? const []) {
        final m = Map<String, dynamic>.from(v as Map);
        final locale = (m['locale'] ?? '').toString();
        final name = (m['name'] ?? '').toString();
        if (name.isEmpty) continue;
        if (locale.toLowerCase().replaceAll('_', '-').split('-').first == lang) {
          list.add({'name': name, 'locale': locale});
        }
      }
      list.sort((a, b) => a['name']!.compareTo(b['name']!));
      if (mounted) setState(() => _voices = list);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _speak() async {
    final app = context.read<AppState>();
    await app.say(tr('voice_sample', {'pet': app.petName}));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('voice_title'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text(tr('voice_intro', {'pet': app.petName})),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in _presets)
            ChoiceChip(
              label: Text('${p.$2} ${tr(p.$1)}'),
              selected: (app.voicePitch - p.$3).abs() < 0.01 && (app.voiceRate - p.$4).abs() < 0.01,
              onSelected: (_) {
                app.update((s) {
                  s.voicePitch = p.$3;
                  s.voiceRate = p.$4;
                });
                _speak();
              },
            ),
        ]),
        SectionCard(
          title: tr('voice_tune'),
          icon: Icons.tune_rounded,
          child: Column(children: [
            Row(children: [
              SizedBox(width: 90, child: Text(tr('voice_pitch'))),
              Expanded(
                child: Slider(
                  value: app.voicePitch.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  label: app.voicePitch.toStringAsFixed(2),
                  onChanged: (v) => setState(() => app.voicePitch = v),
                  onChangeEnd: (v) => app.update((s) => s.voicePitch = v),
                ),
              ),
            ]),
            Row(children: [
              SizedBox(width: 90, child: Text(tr('voice_speed'))),
              Expanded(
                child: Slider(
                  value: app.voiceRate.clamp(0.25, 0.8),
                  min: 0.25,
                  max: 0.8,
                  divisions: 22,
                  label: app.voiceRate.toStringAsFixed(2),
                  onChanged: (v) => setState(() => app.voiceRate = v),
                  onChangeEnd: (v) => app.update((s) => s.voiceRate = v),
                ),
              ),
            ]),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(onPressed: _speak, icon: const Icon(Icons.volume_up_rounded), label: Text(tr('test_alert'))),
            ),
          ]),
        ),
        SectionCard(
          title: tr('voice_list'),
          icon: Icons.record_voice_over_rounded,
          child: _loading
              ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  RadioGroup<String>(
                    groupValue: app.voiceName,
                    onChanged: (v) {
                      final voice = _voices.where((e) => e['name'] == (v ?? '')).firstOrNull;
                      app.update((s) {
                        s.voiceName = v ?? '';
                        s.voiceLocale = voice?['locale'] ?? '';
                      });
                      _speak();
                    },
                    child: Column(children: [
                      RadioListTile<String>(contentPadding: EdgeInsets.zero, value: '', title: Text(tr('voice_default'))),
                      for (final v in _voices)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: v['name']!,
                          title: Text(v['name']!),
                          subtitle: Text(v['locale']!),
                        ),
                    ]),
                  ),
                  if (_voices.isEmpty) Text(tr('voice_none'), style: Theme.of(context).textTheme.bodySmall),
                ]),
        ),
      ]),
    );
  }
}
