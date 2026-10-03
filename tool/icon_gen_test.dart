// Renders the ShieldPal logo (guardian pet inside a shield) in every size the
// app needs, from the same code that draws the pet.
// Run:  flutter test tool/icon_gen_test.dart
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shieldpal/widgets/pet_view.dart';

Future<void> _render(WidgetTester tester, Widget w, String path, {int size = 1024}) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: RepaintBoundary(key: key, child: SizedBox(width: 1024, height: 1024, child: w))),
  ));
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: size / 1024);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

const _bg = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B4BFF), Color(0xFF2F7BFF), Color(0xFF22C7E6)],
  ),
);

/// A big glowing shield with a check badge. [scale] shrinks it for the adaptive-icon safe zone.
class _ShieldPainter extends CustomPainter {
  final double scale;
  _ShieldPainter(this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.translate(s / 2, s / 2);
    canvas.scale(scale);
    canvas.translate(-s / 2, -s / 2);
    final w = s * 0.74, h = s * 0.84;
    final left = (s - w) / 2, top = s * 0.09;
    final p = Path()
      ..moveTo(s / 2, top)
      ..cubicTo(s / 2 + w * 0.18, top + h * 0.07, s / 2 + w * 0.36, top + h * 0.1, left + w, top + h * 0.12)
      ..lineTo(left + w, top + h * 0.5)
      ..cubicTo(left + w, top + h * 0.78, s / 2 + w * 0.2, top + h * 0.93, s / 2, top + h)
      ..cubicTo(s / 2 - w * 0.2, top + h * 0.93, left, top + h * 0.78, left, top + h * 0.5)
      ..lineTo(left, top + h * 0.12)
      ..cubicTo(s / 2 - w * 0.36, top + h * 0.1, s / 2 - w * 0.18, top + h * 0.07, s / 2, top)
      ..close();
    // glow
    canvas.drawPath(
      p,
      Paint()
        ..color = const Color(0xFF8AF3FF).withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38),
    );
    // body
    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFD8E8FF)],
        ).createShader(Rect.fromLTWH(left, top, w, h)),
    );
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    // stars
    final star = Paint()..color = const Color(0xFFFFE066);
    for (final o in [Offset(s * 0.16, s * 0.22), Offset(s * 0.85, s * 0.30), Offset(s * 0.80, s * 0.80)]) {
      final r = s * 0.022;
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final rr = i.isEven ? r : r * 0.45;
        final a = -pi / 2 + i * pi / 5;
        final pt = Offset(o.dx + cos(a) * rr * 1.6, o.dy + sin(a) * rr * 1.6);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path..close(), star);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

Widget _logo({double scale = 1, bool background = true}) {
  const pet = PetLook(skin: 0);
  return Container(
    decoration: background ? _bg : null,
    child: Stack(alignment: Alignment.center, children: [
      Positioned.fill(child: CustomPaint(painter: _ShieldPainter(scale))),
      Transform.translate(
        offset: Offset(0, 40 * scale),
        child: Transform.scale(scale: scale, child: const PetStatic(size: 760, look: pet)),
      ),
    ]),
  );
}

void main() {
  testWidgets('generate icons', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;

    await _render(tester, _logo(), 'assets/icon/icon_1024.png');
    await _render(
      tester,
      ClipRRect(borderRadius: BorderRadius.circular(224), child: _logo()),
      'assets/icon/icon_rounded.png',
    );
    await _render(tester, _logo(scale: 0.78, background: false), 'assets/icon/foreground.png');
    await _render(tester, Container(decoration: _bg), 'assets/icon/background.png');
    await _render(tester, ClipRRect(borderRadius: BorderRadius.circular(224), child: _logo()), 'docs/img/logo.png', size: 1024);

    // Android launcher icons.
    const res = 'android/app/src/main/res';
    const dens = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final e in dens.entries) {
      final dir = '$res/mipmap-${e.key}';
      await _render(
        tester,
        ClipRRect(borderRadius: BorderRadius.circular(224), child: _logo()),
        '$dir/ic_launcher.png',
        size: e.value,
      );
      await _render(tester, _logo(scale: 0.78, background: false), '$dir/ic_launcher_foreground.png', size: e.value * 108 ~/ 48);
      await _render(tester, Container(decoration: _bg), '$dir/ic_launcher_background.png', size: e.value * 108 ~/ 48);
    }

    await _render(tester, ClipRRect(borderRadius: BorderRadius.circular(0), child: _logo()), 'store/play_icon_512.png', size: 512);

    // Web.
    await _render(tester, _logo(), 'web/icons/Icon-512.png', size: 512);
    await _render(tester, _logo(), 'web/icons/Icon-192.png', size: 192);
    await _render(tester, _logo(scale: 0.8), 'web/icons/Icon-maskable-512.png', size: 512);
    await _render(tester, _logo(scale: 0.8), 'web/icons/Icon-maskable-192.png', size: 192);
    await _render(tester, _logo(), 'web/favicon.png', size: 64);
  });
}
