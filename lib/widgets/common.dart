import 'dart:math';

import 'package:flutter/material.dart';

import '../core/url_analyzer.dart';
import '../l10n/l10n.dart';

const brandBlue = Color(0xFF3A8DFF);
const brandAqua = Color(0xFF5EE7DF);
const brandPink = Color(0xFFFF4D8D);
const safeGreen = Color(0xFF22C55E);
const warnAmber = Color(0xFFF59E0B);
const dangerRed = Color(0xFFEF4444);

const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF6A5CFF), brandBlue, Color(0xFF34C6E0)],
);

Color verdictColor(Verdict v) => switch (v) {
      Verdict.safe => safeGreen,
      Verdict.suspicious => warnAmber,
      Verdict.dangerous => dangerRed,
    };

IconData verdictIcon(Verdict v) => switch (v) {
      Verdict.safe => Icons.verified_rounded,
      Verdict.suspicious => Icons.warning_amber_rounded,
      Verdict.dangerous => Icons.dangerous_rounded,
    };

String verdictTitle(Verdict v) => switch (v) {
      Verdict.safe => tr('v_safe'),
      Verdict.suspicious => tr('v_suspicious'),
      Verdict.dangerous => tr('v_dangerous'),
    };

Verdict verdictForScore(int s) => s >= 60
    ? Verdict.dangerous
    : s >= 25
        ? Verdict.suspicious
        : Verdict.safe;

class VerdictBanner extends StatelessWidget {
  final Verdict verdict;
  final int score;
  final String? subtitle;
  const VerdictBanner({super.key, required this.verdict, required this.score, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = verdictColor(verdict);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          border: Border.all(color: c.withValues(alpha: 0.6), width: 2),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(verdictIcon(verdict), color: c, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(verdictTitle(verdict),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            ScoreRing(value: score, color: c, size: 58, label: tr('risk')),
          ],
        ),
      ),
    );
  }
}

class ScoreRing extends StatelessWidget {
  final int value;
  final Color color;
  final double size;
  final String? label;
  const ScoreRing({super.key, required this.value, required this.color, this.size = 64, this.label});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v / 100, color, Theme.of(context).colorScheme.surfaceContainerHighest),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${v.round()}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.28, color: color)),
                if (label != null) Text(label!, style: TextStyle(fontSize: size * 0.13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double p;
  final Color c, bg;
  _RingPainter(this.p, this.c, this.bg);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final base = Paint()
      ..color = bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09;
    canvas.drawArc(r, 0, 2 * pi, false, base);
    canvas.drawArc(r, -pi / 2, 2 * pi * p.clamp(0, 1), false,
        base
          ..color = c
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.p != p || o.c != c;
}

class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final EdgeInsets padding;
  const SectionCard({super.key, this.title, this.icon, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(children: [
                if (icon != null) ...[Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8)],
                Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final double height;
  const GradientButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.gradient = brandGradient,
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        borderRadius: BorderRadius.circular(height / 2),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shadowColor: brandBlue.withValues(alpha: 0.4),
        child: Ink(
          decoration: BoxDecoration(gradient: gradient),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ToolTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
  const ToolTile({super.key, required this.emoji, required this.title, required this.subtitle, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const Spacer(),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                // Flexible so long translations shrink instead of overflowing.
                Flexible(
                  flex: 3,
                  child: Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FindingTile extends StatelessWidget {
  final String code;
  final String detail;
  final int weight;
  const FindingTile({super.key, required this.code, this.detail = '', this.weight = 0});

  @override
  Widget build(BuildContext context) {
    final c = weight >= 35 ? dangerRed : weight >= 12 ? warnAmber : Colors.blueGrey;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(weight >= 35 ? Icons.error_rounded : Icons.info_rounded, color: c),
      title: Text(tr(code, {'x': detail})),
      subtitle: detail.isNotEmpty && !tr(code).contains('{x}') ? Text(detail) : null,
    );
  }
}

void showSnack(BuildContext context, String text, {Color? color}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color, behavior: SnackBarBehavior.floating));
}

class CoinBadge extends StatelessWidget {
  final int coins;
  const CoinBadge({super.key, required this.coins});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFFFF3C4), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🪙', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text('$coins', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF8A5A00))),
      ]),
    );
  }
}
