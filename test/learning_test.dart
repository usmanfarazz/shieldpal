import 'package:flutter_test/flutter_test.dart';
import 'package:shieldpal/core/scam_engine.dart';

void main() {
  test('model learns from the user\'s corrections', () {
    final e = ScamEngine.instance;
    const msg = 'Bhai kal wali party ka hisaab bhej do abhi easypaisa karo warna dekh lena zaroor';
    final before = e.analyze(msg).score;
    for (var i = 0; i < 3; i++) {
      e.learn(msg, 1);
    }
    final after = e.analyze(msg).score;
    // ignore: avoid_print
    print('score before=$before after teaching=$after');
    expect(after, greaterThan(before));
  });
}
