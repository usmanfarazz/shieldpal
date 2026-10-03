import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/assistant.dart';
import '../core/secure_store.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pet_view.dart';
import 'online_services_screen.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _msgs = [];
  bool _thinking = false;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _msgs.add(ChatMessage(false, tr('ai_welcome', {'pet': app.petName})));
    SecureStore.instance.read(SecureStore.claudeKey).then((k) {
      if (mounted) setState(() => _hasKey = (k ?? '').isNotEmpty);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _askFreeAi());
  }

  /// First visit: ask before any chat text is ever sent to the free online AI.
  Future<void> _askFreeAi() async {
    final app = context.read<AppState>();
    if (app.freeAi != 0 || !mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Text('✨', style: TextStyle(fontSize: 36)),
        title: Text(tr('free_ai_ask_title')),
        content: Text(tr('free_ai_ask_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('free_ai_no'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('free_ai_yes'))),
        ],
      ),
    );
    if (mounted) app.update((s) => s.freeAi = yes == true ? 1 : 2);
  }

  String _modeLabel(AppState app) {
    if (app.assistantOnline && _hasKey) return tr('ai_online_claude');
    if (app.freeAi == 1) return tr('ai_online_free');
    return tr('ai_offline');
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _c.text).trim();
    if (text.isEmpty || _thinking) return;
    final app = context.read<AppState>();
    _c.clear();
    setState(() {
      _msgs.add(ChatMessage(true, text));
      _thinking = true;
    });
    _toBottom();
    final lang = LangDetect.detect(text, app.lang);
    final history = _msgs.skip(1).toList();
    final langName = LangDetect.englishName(lang);
    String? reply;
    final quick = Assistant.isSmallTalk(text);
    if (!quick && app.assistantOnline && _hasKey) {
      try {
        reply = await Assistant.online(history, app.petName, langName);
      } catch (_) {
        reply = null; // fall through to the free AI / offline brain
      }
    }
    if (!quick && reply == null && app.freeAi == 1) {
      try {
        reply = await Assistant.freeOnline(history, app.petName, langName);
      } catch (_) {
        reply = null;
      }
    }
    final answer = reply ?? Assistant.offlineReply(text, app.petName, replyLang: lang);
    if (!mounted) return;
    setState(() {
      _msgs.add(ChatMessage(false, answer));
      _thinking = false;
    });
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final suggestions = [for (var i = 1; i <= 8; i++) tr('sug_$i')];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          PetView(mood: _thinking ? PetMood.ok : PetMood.happy, look: app.look, size: 40),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pal AI', style: TextStyle(fontWeight: FontWeight.w900)),
              Text(_modeLabel(app),
                  overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: tr('clear_chat'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {
              _msgs
                ..clear()
                ..add(ChatMessage(false, tr('ai_welcome', {'pet': app.petName})));
            }),
          ),
          IconButton(
            tooltip: tr('ai_settings'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnlineServicesScreen()));
              final k = await SecureStore.instance.read(SecureStore.claudeKey);
              if (mounted) setState(() => _hasKey = (k ?? '').isNotEmpty);
            },
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length + (_thinking ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _msgs.length) {
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(padding: const EdgeInsets.all(8), child: Text('${app.petName} ${tr('ai_typing')}')),
                );
              }
              final m = _msgs[i];
              return Align(
                alignment: m.fromUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: m.fromUser ? brandGradient : null,
                    color: m.fromUser ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SelectableText(m.text, style: TextStyle(color: m.fromUser ? Colors.white : null)),
                ),
              );
            },
          ),
        ),
        if (_msgs.length <= 1)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in suggestions)
                  Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(s), onPressed: () => _send(s))),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(hintText: tr('ai_hint')),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _thinking ? null : _send, icon: const Icon(Icons.send_rounded)),
            ]),
          ),
        ),
      ]),
    );
  }
}
