import 'dart:io';

import 'package:flutter/material.dart';

import 'memes.dart';
import 'native.dart';
import 'theme.dart';

/// Pick pictures from your gallery. DoomPal keeps private copies on this phone and uses them
/// on the Today screen, in memes and in the joke ads.
class PicturesPage extends StatefulWidget {
  const PicturesPage({super.key});

  @override
  State<PicturesPage> createState() => _PicturesPageState();
}

class _PicturesPageState extends State<PicturesPage> {
  List<String> _pics = [];
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await Native.listPictures();
      MemeBank.pictures = p;
      if (!mounted) return;
      setState(() {
        _pics = p;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _add({bool files = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final before = _pics.length;
      final added = await Native.pickPictures(files: files);
      await _load();
      if (!mounted) return;
      if (added == 0 && _pics.length == before) {
        _say('Nothing added.');
      } else {
        _say(added == 1 ? 'Added 1 picture.' : 'Added $added pictures.');
      }
    } catch (_) {
      if (mounted) _say('Couldn\'t open the photo picker on this phone.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this picture?'),
        content: const Text('DoomPal deletes its copy. The original stays in your gallery.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it', style: TextStyle(color: Palette.white)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Palette.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Native.removePicture(path);
      await _load();
    }
  }

  Future<void> _removeAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove all pictures?'),
        content: const Text('DoomPal deletes its copies. Your gallery isn\'t touched.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep them', style: TextStyle(color: Palette.white)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Palette.danger),
            child: const Text('Remove all'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Native.clearPictures();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your pictures')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Text(
            'Add pictures and stickers. Doomy puts captions on them and uses them on the Today screen, '
            'in memes and in the joke ads.',
            style: Txt.quiet,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _add(),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('From gallery'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _add(files: true),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('From files'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Copies stay inside DoomPal on this phone and nothing is uploaded. '
            'They can pop up on the block screen, so only add pictures you\'re fine seeing there.',
            style: Txt.small,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stickers from Sticker.ly or other apps', style: Txt.title),
                SizedBox(height: 8),
                Text(
                  'Save the sticker to your phone in that app, then add it here with "From gallery" or '
                  '"From files". WebP stickers and animated ones work too.',
                  style: Txt.quiet,
                ),
                SizedBox(height: 8),
                Text(
                  'Or tap Share in that app and choose DoomPal. The sticker lands here straight away, '
                  'if the app offers sharing.',
                  style: Txt.quiet,
                ),
                SizedBox(height: 8),
                Text(
                  'DoomPal can\'t browse Sticker.ly itself. It has no internet access, on purpose.',
                  style: Txt.small,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (_loaded && _pics.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Palette.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Palette.line),
              ),
              child: const Text(
                'No pictures yet. Until you add some, Doomy puts the captions on himself.',
                style: Txt.quiet,
              ),
            )
          else ...[
            Text('${_pics.length} ${_pics.length == 1 ? 'picture' : 'pictures'}  ·  tap one to remove it',
                style: Txt.small),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: _pics.length,
              itemBuilder: (context, i) {
                final path = _pics[i];
                return Semantics(
                  button: true,
                  label: 'Picture ${i + 1}. Tap to remove.',
                  child: InkWell(
                    onTap: () => _remove(path),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        cacheWidth: 320,
                        errorBuilder: (context, error, stack) => const ColoredBox(color: Palette.card),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: _removeAll,
              style: TextButton.styleFrom(foregroundColor: Palette.danger),
              child: const Text('Remove all pictures'),
            ),
          ],
        ],
      ),
    );
  }
}
