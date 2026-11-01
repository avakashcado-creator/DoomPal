import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// A chunky bar showing how much of today's limit is gone. Turns red once you're over.
class LimitBar extends StatelessWidget {
  final int count;
  final int limit;
  const LimitBar({super.key, required this.count, required this.limit});

  @override
  Widget build(BuildContext context) {
    final f = limit <= 0 ? 0.0 : (count / limit).clamp(0.0, 1.0).toDouble();
    final over = limit > 0 && count >= limit;
    return Semantics(
      label: '$count of $limit used',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 12,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Palette.bubble)),
              FractionallySizedBox(
                widthFactor: f,
                child: ColoredBox(color: over ? Palette.danger : Palette.doomy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DayBar {
  final String label;
  final int count;
  final bool today;
  const DayBar(this.label, this.count, this.today);
}

/// Seven columns, one per day. Days over the limit are red.
class WeekChart extends StatelessWidget {
  final List<DayBar> days;
  final int limit;
  const WeekChart({super.key, required this.days, required this.limit});

  @override
  Widget build(BuildContext context) {
    final desc = days.map((d) => '${d.label} ${d.count}').join(', ');
    return Semantics(
      label: 'Last 7 days: $desc',
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: CustomPaint(painter: _WeekPainter(days, limit)),
      ),
    );
  }
}

class _WeekPainter extends CustomPainter {
  final List<DayBar> days;
  final int limit;
  _WeekPainter(this.days, this.limit);

  void _text(Canvas c, String s, TextStyle style, Offset center) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const labelH = 22.0;
    const topPad = 22.0;
    final chartH = size.height - labelH - topPad;
    var maxV = limit > 0 ? limit : 1;
    for (final d in days) {
      if (d.count > maxV) maxV = d.count;
    }
    final colW = size.width / days.length;
    final barW = math.min(28.0, colW * 0.5);
    final baseY = topPad + chartH;
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), Paint()..color = Palette.line);
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final cx = colW * i + colW / 2;
      final h = d.count == 0 ? 0.0 : math.max(4.0, chartH * d.count / maxV);
      final over = limit > 0 && d.count > limit;
      final color = over ? Palette.danger : Palette.doomy;
      if (h > 0) {
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(cx - barW / 2, baseY - h, cx + barW / 2, baseY,
              topLeft: const Radius.circular(6), topRight: const Radius.circular(6)),
          Paint()..color = d.today ? color : color.withValues(alpha: 0.5),
        );
        _text(
            canvas,
            '${d.count}',
            Txt.small.copyWith(color: d.today ? Palette.white : Palette.muted, fontSize: 12),
            Offset(cx, baseY - h - 11));
      }
      _text(
        canvas,
        d.label,
        Txt.small.copyWith(
          color: d.today ? Palette.white : Palette.muted,
          fontWeight: d.today ? FontWeight.w600 : FontWeight.w400,
        ),
        Offset(cx, baseY + labelH / 2 + 2),
      );
    }
    if (limit > 0) {
      final ly = baseY - chartH * limit / maxV;
      final dash = Paint()
        ..color = Palette.muted.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, ly), Offset(math.min(x + 4, size.width), ly), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_WeekPainter old) => true;
}

class StatusDot extends StatelessWidget {
  final bool on;
  const StatusDot({super.key, required this.on});

  @override
  Widget build(BuildContext context) {
    final c = on ? Palette.live : Palette.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(on ? 'watching' : 'not watching', style: Txt.small.copyWith(color: c)),
      ],
    );
  }
}

class Chip2 extends StatelessWidget {
  final String text;
  const Chip2(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Palette.line)),
      child: Text(text, style: Txt.small.copyWith(color: Palette.white, fontSize: 14)),
    );
  }
}

class Choice<T> {
  final T value;
  final String label;
  const Choice(this.value, this.label);
}

Future<T?> pickChoice<T>(
  BuildContext context, {
  required String title,
  String? note,
  required List<Choice<T>> choices,
  required T current,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final maxH = MediaQuery.of(ctx).size.height * 0.7;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 4), child: Text(title, style: Txt.title)),
              if (note != null)
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Text(note, style: Txt.quiet)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    for (final c in choices)
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop(c.value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(c.label,
                                    style: Txt.body
                                        .copyWith(color: c.value == current ? Palette.doomy : Palette.white)),
                              ),
                              if (c.value == current) const Icon(Icons.check, color: Palette.doomy, size: 20),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
