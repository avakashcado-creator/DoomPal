import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Every image in assets/memes (shown as-is) and assets/templates (captioned by Doomy).
/// Add files to those folders on GitHub and they show up here, no code changes.
class MemeBank {
  static List<String> memes = [];
  static List<String> templates = [];
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final all = manifest.listAssets();
      bool isImage(String a) {
        final l = a.toLowerCase();
        return l.endsWith('.png') ||
            l.endsWith('.jpg') ||
            l.endsWith('.jpeg') ||
            l.endsWith('.gif') ||
            l.endsWith('.webp');
      }

      memes = all.where((a) => a.startsWith('assets/memes/') && isImage(a)).toList()..sort();
      templates = all.where((a) => a.startsWith('assets/templates/') && isImage(a)).toList()
        ..sort();
      _loaded = true;
    } catch (_) {}
  }

  /// Same template all day, so the Today card doesn't flicker.
  static String? templateOfTheDay() {
    if (templates.isEmpty) return null;
    final d = DateTime.now();
    return templates[(d.year * 400 + d.month * 31 + d.day) % templates.length];
  }

  static String? randomAny(math.Random r) {
    final all = [...memes, ...templates];
    if (all.isEmpty) return null;
    return all[r.nextInt(all.length)];
  }

  static bool isTemplate(String path) => path.startsWith('assets/templates/');
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

/// A square meme. Templates get top and bottom captions; finished memes are shown as they are.
class MemeCard extends StatelessWidget {
  final String? image;
  final String top;
  final String bottom;
  final double captionSize;
  const MemeCard(
      {super.key,
      required this.image,
      required this.top,
      required this.bottom,
      this.captionSize = 30});

  @override
  Widget build(BuildContext context) {
    final img = image;
    final captioned = img == null || MemeBank.isTemplate(img);
    return Semantics(
      label: captioned ? 'Meme: $top. $bottom' : 'Meme picture',
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
                  Image.asset(img,
                      fit: captioned ? BoxFit.cover : BoxFit.contain, gaplessPlayback: true)
                else
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Image.asset('assets/doomy/shocked.png', fit: BoxFit.contain),
                  ),
                if (captioned) ...[
                  Positioned(
                      left: 12, right: 12, top: 10, child: MemeCaption(top, size: captionSize)),
                  Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: MemeCaption(bottom, size: captionSize)),
                ],
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
