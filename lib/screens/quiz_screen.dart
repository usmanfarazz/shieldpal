import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/quiz_data.dart';
import '../core/quiz_generator.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pet_view.dart';

/// "Scam or Safe?" - swipe left for scam, right for safe, against the clock.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const rounds = 10;
  static const secondsPerCard = 12;
  late List<QuizCard> _deck;
  int _i = 0, _correct = 0, _combo = 0, _bestCombo = 0, _left = secondsPerCard;
  double _drag = 0;
  bool? _lastRight;
  bool _showWhy = false;
  bool _finished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _deck = QuizGenerator.deck(rounds);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _left = secondsPerCard;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_showWhy || _finished) return;
      setState(() => _left--);
      if (_left <= 0) _answer(null);
    });
  }

  void _answer(bool? saidScam) {
    if (_showWhy) return;
    final card = _deck[_i];
    final right = saidScam != null && saidScam == card.isScam;
    HapticFeedback.lightImpact();
    setState(() {
      _lastRight = right;
      _showWhy = true;
      _drag = 0;
      if (right) {
        _correct++;
        _combo++;
        _bestCombo = max(_bestCombo, _combo);
      } else {
        _combo = 0;
      }
    });
  }

  void _next() {
    if (_i + 1 >= _deck.length) {
      _timer?.cancel();
      context.read<AppState>().recordQuiz(_correct, _deck.length);
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _i++;
      _showWhy = false;
      _lastRight = null;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('quiz_title')),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${min(_i + 1, rounds)}/$rounds'))),
        ],
      ),
      body: _finished ? _summary(context) : _game(context),
    );
  }

  Widget _game(BuildContext context) {
    final card = _deck[_i];
    final tilt = _drag / 300;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Text('⏱️ $_left', style: TextStyle(fontWeight: FontWeight.w900, color: _left <= 3 ? dangerRed : null)),
          const Spacer(),
          if (_combo >= 2) Text('🔥 x$_combo', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFF97316))),
          const SizedBox(width: 12),
          Text('✅ $_correct'),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _left / secondsPerCard, borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 16),
        Expanded(
          child: GestureDetector(
            onHorizontalDragUpdate: _showWhy ? null : (d) => setState(() => _drag += d.delta.dx),
            onHorizontalDragEnd: _showWhy
                ? null
                : (_) {
                    if (_drag < -90) {
                      _answer(true);
                    } else if (_drag > 90) {
                      _answer(false);
                    } else {
                      setState(() => _drag = 0);
                    }
                  },
            child: Transform.translate(
              offset: Offset(_drag, 0),
              child: Transform.rotate(
                angle: tilt * 0.3,
                child: Card(
                  elevation: 6,
                  color: _drag < -40
                      ? dangerRed.withValues(alpha: 0.12)
                      : _drag > 40
                          ? safeGreen.withValues(alpha: 0.12)
                          : null,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const CircleAvatar(child: Icon(Icons.person_rounded)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(card.sender, style: const TextStyle(fontWeight: FontWeight.w800))),
                        const Icon(Icons.sms_rounded, color: Colors.grey),
                      ]),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                        ),
                        child: Text(card.message, style: const TextStyle(fontSize: 17)),
                      ),
                      const Spacer(),
                      if (_showWhy) ...[
                        Row(children: [
                          Text(_lastRight == true ? '🎉' : '😵', style: const TextStyle(fontSize: 36)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _lastRight == true ? tr('quiz_right') : tr('quiz_wrong'),
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: _lastRight == true ? safeGreen : dangerRed),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text('${card.isScam ? tr('it_was_scam') : tr('it_was_safe')} ${tr(card.why)}'),
                      ] else
                        Center(child: Text(tr('swipe_hint'), style: Theme.of(context).textTheme.bodySmall)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_showWhy)
          GradientButton(label: tr('next'), icon: Icons.arrow_forward_rounded, onPressed: _next)
        else
          Row(children: [
            Expanded(
              child: GradientButton(
                label: tr('scam'),
                icon: Icons.dangerous_rounded,
                gradient: const LinearGradient(colors: [dangerRed, Color(0xFFF97316)]),
                onPressed: () => _answer(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                label: tr('safe'),
                icon: Icons.verified_rounded,
                gradient: const LinearGradient(colors: [safeGreen, Color(0xFF14B8A6)]),
                onPressed: () => _answer(false),
              ),
            ),
          ]),
      ]),
    );
  }

  Widget _summary(BuildContext context) {
    final app = context.watch<AppState>();
    final great = _correct >= 8;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Center(child: PetView(mood: great ? PetMood.happy : PetMood.ok, look: app.look, size: 200)),
      Center(
        child: Text(tr('quiz_score', {'x': _correct, 'y': _deck.length}),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      ),
      const SizedBox(height: 8),
      Center(child: Text(great ? tr('quiz_great', {'pet': app.petName}) : tr('quiz_ok'), textAlign: TextAlign.center)),
      const SizedBox(height: 8),
      Center(child: Text('🪙 +${_correct * 3}   🔥 ${tr('best_combo')}: $_bestCombo')),
      const SizedBox(height: 24),
      GradientButton(
        label: tr('play_again'),
        icon: Icons.replay_rounded,
        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const QuizScreen())),
      ),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('done'))),
    ]);
  }
}
