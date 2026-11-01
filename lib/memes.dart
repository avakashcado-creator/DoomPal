import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'native.dart';
import 'theme.dart';

/// Your own pictures, picked from your gallery and kept privately inside DoomPal.
class MemeBank {
  static List<String> pictures = [];

  static Future<void> load() async {
    try {
      pictures = await Native.listPictures();
    } catch (_) {}
  }

  /// Same picture all day, so the Today card doesn't flicker.
  static String? pictureOfTheDay() {
    if (pictures.isEmpty) return null;
    final d = DateTime.now();
    return pictures[(d.year * 400 + d.month * 31 + d.day) % pictures.length];
  }

  static String? random(math.Random r) {
    if (pictures.isEmpty) return null;
    return pictures[r.nextInt(pictures.length)];
  }
}

/// White Anton with a black outline, the classic meme caption.
class MemeCaption extends StatelessWidget {
  final String text;
  final double size;
  const MemeCaption(this.text, {super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final upper = text.toUpperCase();
    final style = Txt.meme.copyWith(fontSize: size);
    return Stack(
      children: [
        Text(
          upper,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size / 6
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black,
          ),
        ),
        Text(upper, textAlign: TextAlign.center, style: style),
      ],
    );
  }
}

/// A square meme: one of your pictures with outlined captions, or Doomy if you haven't added any.
class MemeCard extends StatelessWidget {
  final String? image;
  final String top;
  final String bottom;
  final double captionSize;
  const MemeCard({
    super.key,
    required this.image,
    required this.top,
    required this.bottom,
    this.captionSize = 30,
  });

  Widget _doomy() => Padding(
        padding: const EdgeInsets.all(48),
        child: Image.asset('assets/doomy/shocked.png', fit: BoxFit.contain),
      );

  @override
  Widget build(BuildContext context) {
    final img = image;
    return Semantics(
      label: 'Meme: $top. $bottom',
      image: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: Palette.card,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (img != null)
                  Image.file(
                    File(img),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stack) => _doomy(),
                  )
                else
                  _doomy(),
                Positioned(left: 12, right: 12, top: 10, child: MemeCaption(top, size: captionSize)),
                Positioned(left: 12, right: 12, bottom: 10, child: MemeCaption(bottom, size: captionSize)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DoomyAvatar extends StatelessWidget {
  final String expr;
  final double size;
  const DoomyAvatar(this.expr, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/doomy/$expr.png', width: size, height: size, gaplessPlayback: true);
  }
}

/// Doomy's name row: avatar, name, blue tick, handle.
class DoomyHeader extends StatelessWidget {
  final String expr;
  final String when;
  final double size;
  const DoomyHeader({super.key, required this.expr, this.when = 'now', this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DoomyAvatar(expr, size: size),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('Doomy', style: Txt.title),
                  SizedBox(width: 4),
                  Icon(Icons.verified, color: Palette.blue, size: 17),
                ],
              ),
              Text('@doomy · $when', style: Txt.small),
            ],
          ),
        ),
      ],
    );
  }
}

/// A post from Doomy, like a screenshot of a tweet.
class DoomyPost extends StatelessWidget {
  final String expr;
  final String text;
  const DoomyPost({super.key, required this.expr, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DoomyHeader(expr: expr),
          const SizedBox(height: 10),
          Text(text, style: Txt.body.copyWith(fontSize: 17, height: 1.35)),
        ],
      ),
    );
  }
}

/// Doomy, big, with a speech bubble. The first thing on the Today screen so he's impossible to miss.
class DoomySays extends StatefulWidget {
  final String expr;
  final String text;
  const DoomySays({super.key, required this.expr, required this.text});

  @override
  State<DoomySays> createState() => _DoomySaysState();
}

class _DoomySaysState extends State<DoomySays> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _bob,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, still ? 0 : -5 * Curves.easeInOut.transform(_bob.value)),
            child: child,
          ),
          child: DoomyAvatar(widget.expr, size: 132),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Palette.bubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
              border: Border.all(color: Palette.doomy.withValues(alpha: 0.7), width: 2),
            ),
            child: Text(widget.text,
                style: Txt.body.copyWith(fontSize: 18, height: 1.3, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }
}
