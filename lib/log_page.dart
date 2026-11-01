import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native.dart';
import 'theme.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  String _text = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await Native.log();
      if (!mounted) return;
      final lines = t.split('\n').where((l) => l.isNotEmpty).toList();
      setState(() => _text = lines.reversed.join('\n'));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy log',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear log',
            onPressed: () async {
              await Native.clearLog();
              await _load();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: _text.isEmpty
            ? const Text(
                'Nothing yet. Turn on "Keep a detection log" in Rules, open YouTube Shorts and swipe a few times. '
                'The newest lines appear at the top.',
                style: Txt.quiet,
              )
            : SelectableText(
                _text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: Palette.white,
                ),
              ),
      ),
    );
  }
}
