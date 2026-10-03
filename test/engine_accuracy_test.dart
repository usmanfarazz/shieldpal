import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shieldpal/core/quiz_data.dart';
import 'package:shieldpal/core/quiz_generator.dart';
import 'package:shieldpal/core/scam_engine.dart';

/// Checks the scam detector on hundreds of freshly generated messages so it
/// is measured, not guessed. Run: flutter test test/engine_accuracy_test.dart
void main() {
  test('scam engine accuracy on generated + hand-written messages', () {
    final engine = ScamEngine.instance;
    final rnd = Random(7);
    final cards = <QuizCard>[...quizCards];
    for (var i = 0; i < 60; i++) {
      cards.addAll(QuizGenerator.deck(10, random: rnd));
    }
    var scamHit = 0, scamTotal = 0, safeOk = 0, safeTotal = 0;
    final missed = <String>[];
    final falseAlarm = <String>[];
    for (final c in cards) {
      final score = engine.analyze(c.message).score;
      if (c.isScam) {
        scamTotal++;
        if (score >= 30) {
          scamHit++;
        } else {
          missed.add('[$score] ${c.message}');
        }
      } else {
        safeTotal++;
        if (score < 30) {
          safeOk++;
        } else {
          falseAlarm.add('[$score] ${c.message}');
        }
      }
    }
    // ignore: avoid_print
    print('scam caught: $scamHit/$scamTotal  safe passed: $safeOk/$safeTotal');
    for (final m in missed.toSet().take(12)) {
      // ignore: avoid_print
      print('MISSED  $m');
    }
    for (final m in falseAlarm.toSet().take(12)) {
      // ignore: avoid_print
      print('FALSE+  $m');
    }
    expect(scamHit / scamTotal, greaterThan(0.9));
    expect(safeOk / safeTotal, greaterThan(0.9));
  });
}
