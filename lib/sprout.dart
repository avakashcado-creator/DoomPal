import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The sprout in a pot. [health] 1 = fresh, 0 = wilted. [stage] = days in your streak.
/// It grows in when the screen opens and moves smoothly whenever the numbers change.
class Sprout extends StatelessWidget {
  final double health;
  final int stage;
  final double width;
  final String semanticLabel;

  const Sprout({
    super.key,
    required this.health,
    required this.stage,
    required this.semanticLabel,
    this.width = 190,
  });

  /// The drawing is 180 x 240 units; the pot's base sits 4 units above the bottom edge.
  static double heightFor(double width) => width * 240 / 180;
  static double potBaseInset(double width) => width * 4 / 180;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: semanticLabel,
      image: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: health),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 1100),
        curve: Curves.easeInOutCubic,
        builder: (context, h, _) => TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: stage.toDouble()),
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 1500),
          curve: Curves.easeOutCubic,
          builder: (context, st, _) => CustomPaint(
            size: Size(width, heightFor(width)),
            painter: SproutPainter(health: h, stage: st),
          ),
        ),
      ),
    );
  }
}

class SproutPainter extends CustomPainter {
  final double health;
  final double stage;

  SproutPainter({required this.health, required this.stage});

  static const _leaf = Color(0xFF8CC97E);
  static const _dry = Color(0xFF936E47);
  static const _pot = Color(0xFF34503F);
  static const _rim = Color(0xFF3F6150);
  static const _soil = Color(0xFF20180F);
  static const _shine = Color(0xFF456B59);

  static double _smooth(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  static Color _leafColor(double wilt) {
    if (wilt < 0.5) return Color.lerp(_leaf, Palette.straw, wilt * 2)!;
    return Color.lerp(Palette.straw, _dry, (wilt - 0.5) * 2)!;
  }

  static void _oval(
      Canvas c, Offset center, double rx, double ry, double angle, Paint p) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), p);
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 180.0;
    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(-60, -40);

    final wilt = _smooth((0.8 - health) / 0.8);
    final g = stage.clamp(0.0, 7.0);
    const base = Offset(150, 214);
    final stemLen = 58 + 13 * math.min(g, 6.0);
    final bend = 150 * math.pi / 180 * wilt;
    const lean = -6 * math.pi / 180;

    // Stem: integrate a curve whose angle grows towards the top, so a wilting head hangs.
    const n = 36;
    final pts = <Offset>[base];
    final angs = <double>[lean];
    var x = base.dx;
    var y = base.dy;
    final seg = stemLen / n;
    for (var i = 1; i <= n; i++) {
      final s = i / n;
      final a = lean + bend * math.pow(s, 2.6);
      x += math.sin(a) * seg;
      y -= math.cos(a) * seg;
      pts.add(Offset(x, y));
      angs.add(a);
    }

    final lc = _leafColor(wilt);
    final rib = Color.lerp(lc, const Color(0xFF2E452E), 0.32)!;
    final stemColor = Color.lerp(lc, const Color(0xFF4E6E48), 0.35)!;
    final fill = Paint()..isAntiAlias = true;

    // Pot
    final body = Path()
      ..moveTo(98, 222)
      ..lineTo(202, 222)
      ..lineTo(190, 272)
      ..quadraticBezierTo(189, 276, 185, 276)
      ..lineTo(115, 276)
      ..quadraticBezierTo(111, 276, 110, 272)
      ..close();
    canvas.drawPath(body, fill..color = _pot);
    canvas.drawRRect(
      RRect.fromLTRBR(92, 208, 208, 226, const Radius.circular(5)),
      fill..color = _rim,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(150, 211), width: 104, height: 10),
      fill..color = _soil,
    );
    canvas.drawLine(
      const Offset(108, 230),
      const Offset(113, 266),
      Paint()
        ..color = _shine
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Stem
    final stem = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      stem.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      stem,
      Paint()
        ..color = stemColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Leaves: two to start, one more per streak day (up to seven), alternating sides.
    final leafCount = 2 + math.min(g, 5.0);
    final count = leafCount.ceil();
    for (var k = 0; k < count; k++) {
      final grow = (leafCount - k).clamp(0.0, 1.0);
      if (grow <= 0) continue;
      final s = count > 1 ? 0.22 + 0.68 * (k / (count - 1)) : 0.5;
      final idx = (s * n).floor();
      final p = pts[idx];
      final a = angs[idx];
      final side = k.isEven ? -1.0 : 1.0;
      final len = 36 * (1 - 0.38 * s) * grow;
      final wid = len * 0.46;
      final phi = a + side * 58 * math.pi / 180;
      final down = side * 160 * math.pi / 180;
      final tip = phi + (down - phi) * (0.75 * wilt);

      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(tip - math.pi / 2);
      final whole = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.45, -wid, len, 0)
        ..quadraticBezierTo(len * 0.45, wid, 0, 0)
        ..close();
      final half = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.45, -wid, len, 0)
        ..quadraticBezierTo(len * 0.5, -wid * 0.12, 0, 0)
        ..close();
      canvas.drawPath(whole, fill..color = rib);
      canvas.drawPath(half, fill..color = lc);
      canvas.restore();
    }

    // Bud from day 3, flower from day 7. Petals fall when a flowering plant wilts.
    final tipPt = pts.last;
    final ta = angs.last;
    if (g >= 3 && wilt < 0.85) {
      if (g >= 7) {
        final pr = 9 * (1 - 0.6 * wilt);
        for (var i = 0; i < 5; i++) {
          final ang = ta + i * 2 * math.pi / 5;
          final c = Offset(
            tipPt.dx + math.sin(ang) * pr * 0.95,
            tipPt.dy - math.cos(ang) * pr * 0.95,
          );
          _oval(canvas, c, pr * 0.62, pr * 0.95, ang,
              fill..color = Palette.petal);
        }
        canvas.drawCircle(
            tipPt, 4.2 * (1 - 0.3 * wilt), fill..color = Palette.pollen);
      } else {
        final bs = (g - 2).clamp(0.0, 1.0);
        final c =
            Offset(tipPt.dx + math.sin(ta) * 5, tipPt.dy - math.cos(ta) * 5);
        _oval(canvas, c, 5 * bs, 8 * bs, ta, fill..color = Palette.pollen);
      }
    }
    if (g >= 7 && wilt >= 0.85) {
      _oval(canvas, const Offset(128, 210), 5, 2.6, -18 * math.pi / 180,
          fill..color = Palette.petal.withValues(alpha: 0.8));
      _oval(canvas, const Offset(171, 211), 5, 2.6, 24 * math.pi / 180,
          fill..color = Palette.petal.withValues(alpha: 0.7));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(SproutPainter old) =>
      old.health != health || old.stage != stage;
}
