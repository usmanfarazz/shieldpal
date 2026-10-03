import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

enum PetMood { happy, ok, worried, sick, alarmed }

class PetLook {
  final int skin;
  final String hat; // none, cap, crown, wizard, headphones, party, chef
  final String glasses; // none, shades, nerd, star
  final String extra; // none, cape, bowtie, scarf, medal
  final String species; // cat, bunny, bear, dog, fox
  const PetLook({this.skin = 0, this.hat = 'none', this.glasses = 'none', this.extra = 'none', this.species = 'cat'});
}

/// Pets the user can switch between (free, in Settings).
const List<(String, String)> petSpecies = [
  ('cat', '🐱'),
  ('bunny', '🐰'),
  ('bear', '🐻'),
  ('dog', '🐶'),
  ('fox', '🦊'),
];

const List<List<Color>> petSkins = [
  [Color(0xFF5EE7DF), Color(0xFF3A8DFF)], // aqua
  [Color(0xFFFFB86C), Color(0xFFFF6B8B)], // sunset
  [Color(0xFFB28DFF), Color(0xFF6A5CFF)], // grape
  [Color(0xFF9BE15D), Color(0xFF00C389)], // mint
  [Color(0xFFFFE066), Color(0xFFFFA62B)], // honey
  [Color(0xFFFF9AD5), Color(0xFFC86BFA)], // bubblegum
  [Color(0xFF8E9BAE), Color(0xFF3D4A5C)], // stealth
  [Color(0xFFFFFFFF), Color(0xFFBFD7FF)], // snow
];

/// ShieldPal's mascot, drawn entirely in code (no image files), animated.
class PetView extends StatefulWidget {
  final PetMood mood;
  final PetLook look;
  final double size;
  final VoidCallback? onTap;
  const PetView({super.key, required this.mood, this.look = const PetLook(), this.size = 220, this.onTap});

  @override
  State<PetView> createState() => _PetViewState();
}

class _PetViewState extends State<PetView> with TickerProviderStateMixin {
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  late final AnimationController _jump =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _blinkCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  final _rand = Random();
  Timer? _blinkTimer;
  final List<_Heart> _hearts = [];

  double get _blink => _blinkCtrl.value <= 0.5 ? _blinkCtrl.value * 2 : (1 - _blinkCtrl.value) * 2;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  // Blink every few seconds; the timer is cancelled in dispose().
  void _scheduleBlink() {
    _blinkTimer = Timer(Duration(milliseconds: 1800 + _rand.nextInt(2600)), () {
      if (!mounted) return;
      _blinkCtrl.forward(from: 0);
      _scheduleBlink();
    });
  }

  void _tap() {
    _jump.forward(from: 0);
    setState(() {
      for (var i = 0; i < 5; i++) {
        _hearts.add(_Heart(DateTime.now(), _rand.nextDouble() * 2 - 1, _rand.nextDouble()));
      }
    });
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkCtrl.dispose();
    _loop.dispose();
    _jump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ShieldPal pet, mood ${widget.mood.name}',
      button: true,
      child: GestureDetector(
        onTap: _tap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_loop, _jump, _blinkCtrl]),
          builder: (context, _) {
            final now = DateTime.now();
            _hearts.removeWhere((h) => now.difference(h.born).inMilliseconds > 1400);
            return CustomPaint(
              size: Size.square(widget.size),
              painter: _PetPainter(
                t: _loop.value,
                jump: _jump.value,
                blink: _blink,
                mood: widget.mood,
                look: widget.look,
                hearts: _hearts.map((h) => (h.dx, h.speed, now.difference(h.born).inMilliseconds / 1400)).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Heart {
  final DateTime born;
  final double dx;
  final double speed;
  _Heart(this.born, this.dx, this.speed);
}

class _PetPainter extends CustomPainter {
  final double t, jump, blink;
  final PetMood mood;
  final PetLook look;
  final List<(double, double, double)> hearts;

  _PetPainter({
    required this.t,
    required this.jump,
    required this.blink,
    required this.mood,
    required this.look,
    required this.hearts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final phase = t * 2 * pi;

    // Movement per mood.
    double bob = sin(phase) * s * 0.02;
    double shakeX = 0;
    double squash = 1 + sin(phase * 2) * 0.015;
    if (mood == PetMood.happy) bob = -sin(phase * 2).abs() * s * 0.045;
    if (mood == PetMood.sick) {
      bob = sin(phase) * s * 0.008;
      squash = 0.96;
    }
    if (mood == PetMood.alarmed) shakeX = sin(phase * 14) * s * 0.012;
    final jumpY = -sin(jump * pi) * s * 0.12;

    final bodyCenter = Offset(cx + shakeX, s * 0.58 + bob + jumpY);
    final bodyW = s * 0.56;
    final bodyH = s * 0.5 * squash;

    // Glow / aura.
    final auraColor = switch (mood) {
      PetMood.happy => const Color(0xFF4ADE80),
      PetMood.ok => const Color(0xFF60A5FA),
      PetMood.worried => const Color(0xFFFBBF24),
      PetMood.sick => const Color(0xFFA3E635),
      PetMood.alarmed => const Color(0xFFF43F5E),
    };
    final auraPulse = 0.18 + 0.08 * sin(phase * (mood == PetMood.alarmed ? 6 : 2));
    canvas.drawCircle(
      bodyCenter,
      bodyW * 0.85,
      Paint()
        ..shader = RadialGradient(colors: [auraColor.withValues(alpha: auraPulse), auraColor.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: bodyCenter, radius: bodyW * 0.85)),
    );

    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, s * 0.9), width: bodyW * (0.8 - (-jumpY / s)), height: s * 0.05),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );

    // Cape behind body.
    if (look.extra == 'cape') {
      final cape = Path()
        ..moveTo(bodyCenter.dx - bodyW * 0.32, bodyCenter.dy - bodyH * 0.2)
        ..quadraticBezierTo(bodyCenter.dx - bodyW * 0.62, bodyCenter.dy + bodyH * 0.45 + sin(phase * 2) * 4,
            bodyCenter.dx - bodyW * 0.4, bodyCenter.dy + bodyH * 0.5)
        ..lineTo(bodyCenter.dx + bodyW * 0.4, bodyCenter.dy + bodyH * 0.5)
        ..quadraticBezierTo(bodyCenter.dx + bodyW * 0.62, bodyCenter.dy + bodyH * 0.45 - sin(phase * 2) * 4,
            bodyCenter.dx + bodyW * 0.32, bodyCenter.dy - bodyH * 0.2)
        ..close();
      canvas.drawPath(cape, Paint()..color = const Color(0xFFE11D48));
    }

    var colors = petSkins[look.skin.clamp(0, petSkins.length - 1)];
    if (mood == PetMood.sick) {
      colors = [Color.lerp(colors[0], const Color(0xFFB5D99C), 0.6)!, Color.lerp(colors[1], const Color(0xFF7A9A5A), 0.6)!];
    }
    final bodyRect = Rect.fromCenter(center: bodyCenter, width: bodyW, height: bodyH);
    final bodyPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)
          .createShader(bodyRect);

    // Ears (shape depends on the chosen pet).
    final earDroop = mood == PetMood.sick ? 0.35 : mood == PetMood.worried ? 0.15 : 0.0;
    final earInner = Paint()..color = Colors.white.withValues(alpha: 0.45);
    final darker = Paint()..color = Color.lerp(colors[1], const Color(0xFF000000), 0.18)!;
    for (final side in [-1.0, 1.0]) {
      switch (look.species) {
        case 'bunny':
          canvas.save();
          canvas.translate(bodyCenter.dx + side * bodyW * 0.2, bodyCenter.dy - bodyH * 0.34);
          canvas.rotate(side * (0.16 + earDroop * 1.6));
          final r = Rect.fromCenter(center: Offset(0, -bodyH * 0.34), width: bodyW * 0.19, height: bodyH * 0.82);
          canvas.drawOval(r, bodyPaint);
          canvas.drawOval(r.deflate(bodyW * 0.04), Paint()..color = const Color(0xFFFF9EBB).withValues(alpha: 0.7));
          canvas.restore();
        case 'bear':
          final c = Offset(bodyCenter.dx + side * bodyW * 0.33, bodyCenter.dy - bodyH * 0.36 + earDroop * bodyH * 0.15);
          canvas.drawCircle(c, bodyW * 0.14, bodyPaint);
          canvas.drawCircle(c, bodyW * 0.075, earInner);
        case 'dog':
          canvas.save();
          canvas.translate(bodyCenter.dx + side * bodyW * 0.45, bodyCenter.dy - bodyH * 0.12);
          canvas.rotate(side * (0.28 + earDroop * 0.6));
          canvas.drawOval(Rect.fromCenter(center: Offset(0, bodyH * 0.12), width: bodyW * 0.2, height: bodyH * 0.55), darker);
          canvas.restore();
        default:
          final tall = look.species == 'fox' ? 1.3 : 1.0;
          final baseX = bodyCenter.dx + side * bodyW * 0.28;
          final baseY = bodyCenter.dy - bodyH * 0.38;
          final tip = Offset(baseX + side * bodyW * (0.12 + earDroop * 0.4), baseY - bodyH * (0.42 * tall - earDroop));
          final ear = Path()
            ..moveTo(baseX - side * bodyW * 0.14, baseY + 6)
            ..quadraticBezierTo(tip.dx - side * 6, tip.dy, tip.dx, tip.dy)
            ..quadraticBezierTo(tip.dx + side * 2, tip.dy + 10, baseX + side * bodyW * 0.14, baseY + 10)
            ..close();
          canvas.drawPath(ear, bodyPaint);
          final inner = Path()
            ..moveTo(baseX - side * bodyW * 0.07, baseY + 4)
            ..lineTo(Offset.lerp(Offset(baseX, baseY), tip, 0.7)!.dx, Offset.lerp(Offset(baseX, baseY), tip, 0.7)!.dy)
            ..lineTo(baseX + side * bodyW * 0.07, baseY + 6)
            ..close();
          canvas.drawPath(inner, look.species == 'fox' ? (Paint()..color = const Color(0xFF3D2A1E).withValues(alpha: 0.55)) : earInner);
      }
    }

    // Body blob.
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.elliptical(bodyW * 0.48, bodyH * 0.55)), bodyPaint);
    // Shine.
    canvas.drawOval(
      Rect.fromCenter(center: bodyCenter.translate(-bodyW * 0.2, -bodyH * 0.28), width: bodyW * 0.22, height: bodyH * 0.12),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    // Belly shield emblem.
    final shieldC = bodyCenter.translate(0, bodyH * 0.29);
    final sw = bodyW * 0.2;
    final shield = Path()
      ..moveTo(shieldC.dx, shieldC.dy - sw * 0.6)
      ..lineTo(shieldC.dx + sw * 0.55, shieldC.dy - sw * 0.38)
      ..quadraticBezierTo(shieldC.dx + sw * 0.5, shieldC.dy + sw * 0.4, shieldC.dx, shieldC.dy + sw * 0.7)
      ..quadraticBezierTo(shieldC.dx - sw * 0.5, shieldC.dy + sw * 0.4, shieldC.dx - sw * 0.55, shieldC.dy - sw * 0.38)
      ..close();
    canvas.drawPath(shield, Paint()..color = Colors.white.withValues(alpha: 0.9));
    final check = Path()
      ..moveTo(shieldC.dx - sw * 0.22, shieldC.dy)
      ..lineTo(shieldC.dx - sw * 0.04, shieldC.dy + sw * 0.18)
      ..lineTo(shieldC.dx + sw * 0.26, shieldC.dy - sw * 0.2);
    canvas.drawPath(
      check,
      Paint()
        ..color = mood == PetMood.alarmed || mood == PetMood.sick ? const Color(0xFFF43F5E) : colors[1]
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * 0.14
        ..strokeCap = StrokeCap.round,
    );

    // Face.
    final eyeY = bodyCenter.dy - bodyH * 0.08;
    final eyeDx = bodyW * 0.17;
    final eyeR = bodyW * 0.065;
    final dark = Paint()..color = const Color(0xFF1E1B2E);
    for (final side in [-1.0, 1.0]) {
      final c = Offset(bodyCenter.dx + side * eyeDx, eyeY);
      if (mood == PetMood.happy && blink < 0.5) {
        // ^ ^ happy eyes
        final p = Path()
          ..moveTo(c.dx - eyeR, c.dy + eyeR * 0.3)
          ..quadraticBezierTo(c.dx, c.dy - eyeR * 1.2, c.dx + eyeR, c.dy + eyeR * 0.3);
        canvas.drawPath(p, Paint()
          ..color = dark.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = eyeR * 0.45
          ..strokeCap = StrokeCap.round);
      } else if (mood == PetMood.sick) {
        // droopy half-closed eyes
        canvas.drawArc(Rect.fromCircle(center: c, radius: eyeR), 0.1, pi - 0.2, false, Paint()
          ..color = dark.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = eyeR * 0.4
          ..strokeCap = StrokeCap.round);
      } else {
        final r = mood == PetMood.alarmed ? eyeR * 1.35 : eyeR;
        final openH = r * 2 * (1 - blink * 0.92);
        canvas.drawOval(Rect.fromCenter(center: c, width: r * 2, height: openH), dark);
        if (blink < 0.6) {
          canvas.drawCircle(c.translate(-r * 0.3, -r * 0.35), r * 0.32, Paint()..color = Colors.white);
        }
      }
      // Eyebrows when worried / alarmed.
      if (mood == PetMood.worried || mood == PetMood.alarmed) {
        canvas.drawLine(
          Offset(c.dx - side * eyeR * 1.1, c.dy - eyeR * 2.2),
          Offset(c.dx + side * eyeR * 0.9, c.dy - eyeR * 1.6),
          Paint()
            ..color = dark.color
            ..strokeWidth = eyeR * 0.3
            ..strokeCap = StrokeCap.round,
        );
      }
      // Cheeks.
      canvas.drawCircle(
        Offset(bodyCenter.dx + side * eyeDx * 1.65, eyeY + eyeR * 1.6),
        eyeR * 0.75,
        Paint()..color = const Color(0xFFFF7AA2).withValues(alpha: mood == PetMood.sick ? 0.15 : 0.45),
      );
    }

    // Mouth.
    final mouthC = Offset(bodyCenter.dx, eyeY + eyeR * 2.1);
    final mouthPaint = Paint()
      ..color = dark.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = eyeR * 0.35
      ..strokeCap = StrokeCap.round;
    switch (mood) {
      case PetMood.happy:
        final p = Path()
          ..moveTo(mouthC.dx - eyeR * 1.3, mouthC.dy - eyeR * 0.3)
          ..quadraticBezierTo(mouthC.dx, mouthC.dy + eyeR * 1.6, mouthC.dx + eyeR * 1.3, mouthC.dy - eyeR * 0.3)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF3B1F2B));
        canvas.drawCircle(mouthC.translate(0, eyeR * 0.55), eyeR * 0.45, Paint()..color = const Color(0xFFFF6B8B));
      case PetMood.ok:
        canvas.drawArc(Rect.fromCenter(center: mouthC.translate(0, -eyeR * 0.4), width: eyeR * 1.8, height: eyeR * 1.4),
            0.3, pi - 0.6, false, mouthPaint);
      case PetMood.worried:
        canvas.drawOval(Rect.fromCenter(center: mouthC, width: eyeR * 0.9, height: eyeR * 0.7), Paint()..color = dark.color);
      case PetMood.sick:
        final p = Path()..moveTo(mouthC.dx - eyeR * 1.1, mouthC.dy);
        for (var i = 1; i <= 4; i++) {
          p.lineTo(mouthC.dx - eyeR * 1.1 + i * eyeR * 0.55, mouthC.dy + (i.isOdd ? -eyeR * 0.3 : eyeR * 0.3));
        }
        canvas.drawPath(p, mouthPaint);
      case PetMood.alarmed:
        canvas.drawOval(Rect.fromCenter(center: mouthC.translate(0, eyeR * 0.2), width: eyeR * 1.3, height: eyeR * 1.6),
            Paint()..color = const Color(0xFF3B1F2B));
    }

    // Accessories ------------------------------------------------------
    final headTop = Offset(bodyCenter.dx, bodyCenter.dy - bodyH * 0.47);
    _drawGlasses(canvas, Offset(bodyCenter.dx, eyeY), eyeDx, eyeR);
    _drawHat(canvas, headTop, bodyW);
    _drawExtra(canvas, bodyCenter, bodyW, bodyH);

    // Mood props.
    if (mood == PetMood.sick) {
      // thermometer
      final th = Offset(mouthC.dx + eyeR * 1.4, mouthC.dy + eyeR * 0.2);
      canvas.save();
      canvas.translate(th.dx, th.dy);
      canvas.rotate(-0.5);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, -eyeR * 0.25, eyeR * 3, eyeR * 0.5), Radius.circular(eyeR)),
          Paint()..color = Colors.white);
      canvas.drawCircle(Offset(eyeR * 3, 0), eyeR * 0.45, Paint()..color = const Color(0xFFEF4444));
      canvas.restore();
      // sweat / sick bubbles
      for (var i = 0; i < 3; i++) {
        final y = (t + i / 3) % 1;
        canvas.drawCircle(
          Offset(bodyCenter.dx + bodyW * (0.45 + i * 0.05), bodyCenter.dy - bodyH * 0.2 - y * s * 0.25),
          s * 0.012 * (1 - y) + 1,
          Paint()..color = const Color(0xFF84CC16).withValues(alpha: 1 - y),
        );
      }
    }
    if (mood == PetMood.alarmed) {
      final tp = TextPainter(
        text: TextSpan(text: '!', style: TextStyle(fontSize: s * 0.16, fontWeight: FontWeight.w900, color: const Color(0xFFF43F5E))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(bodyCenter.dx + bodyW * 0.42, bodyCenter.dy - bodyH * 0.95 + sin(phase * 8) * 3));
    }
    if (mood == PetMood.worried) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bodyCenter.dx + bodyW * 0.36, eyeY - eyeR * 1.5), width: eyeR * 0.7, height: eyeR * 1.1),
        Paint()..color = const Color(0xFF7DD3FC),
      );
    }
    if (mood == PetMood.happy) {
      for (var i = 0; i < 4; i++) {
        final a = phase + i * pi / 2;
        final p = Offset(cx + cos(a) * s * 0.42, s * 0.45 + sin(a) * s * 0.3);
        _star(canvas, p, s * 0.018 * (1 + 0.4 * sin(phase * 3 + i)), const Color(0xFFFDE047));
      }
    }

    // Hearts after a tap.
    for (final (dx, speed, life) in hearts) {
      final p = Offset(cx + dx * s * 0.25, s * 0.35 - life * s * (0.25 + speed * 0.15));
      _heart(canvas, p, s * 0.035, const Color(0xFFFF4D8D).withValues(alpha: (1 - life).clamp(0, 1)));
    }
  }

  void _drawGlasses(Canvas canvas, Offset c, double dx, double r) {
    final frame = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.28;
    switch (look.glasses) {
      case 'shades':
        final p = Paint()..color = const Color(0xFF111827);
        for (final side in [-1.0, 1.0]) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(side * dx, 0), width: r * 3, height: r * 2), Radius.circular(r * 0.6)),
              p);
          canvas.drawLine(c.translate(side * dx - r * 0.9, -r * 0.4), c.translate(side * dx - r * 0.3, -r * 0.4),
              Paint()
                ..color = Colors.white54
                ..strokeWidth = r * 0.25);
        }
        canvas.drawLine(c.translate(-dx + r * 1.5, -r * 0.3), c.translate(dx - r * 1.5, -r * 0.3), frame);
      case 'nerd':
        for (final side in [-1.0, 1.0]) {
          canvas.drawCircle(c.translate(side * dx, 0), r * 1.5, frame);
        }
        canvas.drawLine(c.translate(-dx + r * 1.5, 0), c.translate(dx - r * 1.5, 0), frame);
      case 'star':
        for (final side in [-1.0, 1.0]) {
          _star(canvas, c.translate(side * dx, 0), r * 1.7, const Color(0xFFF472B6), stroke: true);
        }
      default:
        break;
    }
  }

  void _drawHat(Canvas canvas, Offset top, double w) {
    switch (look.hat) {
      case 'cap':
        final p = Paint()..color = const Color(0xFF2563EB);
        canvas.drawArc(Rect.fromCenter(center: top.translate(0, w * 0.08), width: w * 0.62, height: w * 0.42), pi, pi, true, p);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(top.dx, top.dy + w * 0.03, w * 0.42, w * 0.07), Radius.circular(w * 0.04)), p);
        canvas.drawCircle(top.translate(0, -w * 0.13), w * 0.025, Paint()..color = Colors.white);
      case 'crown':
        final p = Path()
          ..moveTo(top.dx - w * 0.22, top.dy + w * 0.06)
          ..lineTo(top.dx - w * 0.24, top.dy - w * 0.14)
          ..lineTo(top.dx - w * 0.11, top.dy - w * 0.04)
          ..lineTo(top.dx, top.dy - w * 0.2)
          ..lineTo(top.dx + w * 0.11, top.dy - w * 0.04)
          ..lineTo(top.dx + w * 0.24, top.dy - w * 0.14)
          ..lineTo(top.dx + w * 0.22, top.dy + w * 0.06)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFFFACC15));
        for (final x in [-0.11, 0.0, 0.11]) {
          canvas.drawCircle(top.translate(w * x, w * 0.0), w * 0.022, Paint()..color = const Color(0xFFEF4444));
        }
      case 'wizard':
        final p = Path()
          ..moveTo(top.dx - w * 0.26, top.dy + w * 0.07)
          ..quadraticBezierTo(top.dx - w * 0.02, top.dy - w * 0.2, top.dx + w * 0.16, top.dy - w * 0.42)
          ..quadraticBezierTo(top.dx + w * 0.08, top.dy - w * 0.12, top.dx + w * 0.26, top.dy + w * 0.07)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF7C3AED));
        _star(canvas, top.translate(-w * 0.02, -w * 0.08), w * 0.04, const Color(0xFFFDE047));
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: top.translate(0, w * 0.07), width: w * 0.62, height: w * 0.07),
                Radius.circular(w * 0.04)),
            Paint()..color = const Color(0xFF5B21B6));
      case 'headphones':
        final band = Paint()
          ..color = const Color(0xFF111827)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.05;
        canvas.drawArc(Rect.fromCenter(center: top.translate(0, w * 0.2), width: w * 0.92, height: w * 0.7), pi * 1.05, pi * 0.9, false, band);
        for (final side in [-1.0, 1.0]) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: top.translate(side * w * 0.47, w * 0.3), width: w * 0.13, height: w * 0.2),
                  Radius.circular(w * 0.05)),
              Paint()..color = const Color(0xFFEF4444));
        }
      case 'party':
        final p = Path()
          ..moveTo(top.dx - w * 0.13, top.dy + w * 0.04)
          ..lineTo(top.dx + w * 0.02, top.dy - w * 0.3)
          ..lineTo(top.dx + w * 0.15, top.dy + w * 0.04)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFFF472B6));
        canvas.drawCircle(top.translate(w * 0.02, -w * 0.31), w * 0.04, Paint()..color = const Color(0xFFFDE047));
      case 'chef':
        final p = Paint()..color = Colors.white;
        canvas.drawRect(Rect.fromCenter(center: top.translate(0, w * 0.02), width: w * 0.34, height: w * 0.1), p);
        for (final x in [-0.1, 0.0, 0.1]) {
          canvas.drawCircle(top.translate(w * x, -w * 0.08), w * 0.1, p);
        }
      default:
        break;
    }
  }

  void _drawExtra(Canvas canvas, Offset c, double w, double h) {
    final neck = c.translate(0, h * 0.05);
    switch (look.extra) {
      case 'bowtie':
        final p = Paint()..color = const Color(0xFFEF4444);
        final l = Path()
          ..moveTo(neck.dx, neck.dy)
          ..lineTo(neck.dx - w * 0.1, neck.dy - w * 0.05)
          ..lineTo(neck.dx - w * 0.1, neck.dy + w * 0.05)
          ..close();
        final r = Path()
          ..moveTo(neck.dx, neck.dy)
          ..lineTo(neck.dx + w * 0.1, neck.dy - w * 0.05)
          ..lineTo(neck.dx + w * 0.1, neck.dy + w * 0.05)
          ..close();
        canvas.drawPath(l, p);
        canvas.drawPath(r, p);
        canvas.drawCircle(neck, w * 0.025, Paint()..color = const Color(0xFFB91C1C));
      case 'scarf':
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: neck, width: w * 0.62, height: w * 0.08), Radius.circular(w * 0.04)),
            Paint()..color = const Color(0xFF22C55E));
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(neck.dx + w * 0.12, neck.dy, w * 0.08, w * 0.2), Radius.circular(w * 0.03)),
            Paint()..color = const Color(0xFF16A34A));
      case 'medal':
        canvas.drawLine(neck.translate(-w * 0.08, -w * 0.02), neck.translate(0, w * 0.1),
            Paint()
              ..color = const Color(0xFF3B82F6)
              ..strokeWidth = w * 0.03);
        canvas.drawLine(neck.translate(w * 0.08, -w * 0.02), neck.translate(0, w * 0.1),
            Paint()
              ..color = const Color(0xFF3B82F6)
              ..strokeWidth = w * 0.03);
        canvas.drawCircle(neck.translate(0, w * 0.12), w * 0.05, Paint()..color = const Color(0xFFFBBF24));
      default:
        break;
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color, {bool stroke = false}) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = r * 0.18);
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(c.dx - r * 1.6, c.dy - r * 0.2, c.dx - r * 0.6, c.dy - r * 1.3, c.dx, c.dy - r * 0.4)
      ..cubicTo(c.dx + r * 0.6, c.dy - r * 1.3, c.dx + r * 1.6, c.dy - r * 0.2, c.dx, c.dy + r * 0.9)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PetPainter old) => true;
}

/// A still (non-animated) pet, used for the app icon and small badges.
class PetStatic extends StatelessWidget {
  final PetMood mood;
  final PetLook look;
  final double size;
  const PetStatic({super.key, this.mood = PetMood.happy, this.look = const PetLook(), this.size = 200});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _PetPainter(t: 0.06, jump: 0, blink: 0, mood: mood, look: look, hearts: const []),
      );
}
