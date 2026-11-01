import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'apps.dart';
import 'lines.dart';
import 'memes.dart';
import 'native.dart';
import 'theme.dart';

class _Msg {
  final int time;
  final String who; // 'doomy' or 'you'
  final String text;
  const _Msg(this.time, this.who, this.text);
}

/// Chat with Doomy. Everything he said on the overlays shows up here too.
class DoomyPage extends StatefulWidget {
  const DoomyPage({super.key});

  @override
  State<DoomyPage> createState() => _DoomyPageState();
}

class _DoomyPageState extends State<DoomyPage> {
  final _scroll = ScrollController();
  final _rnd = math.Random();
  Timer? _timer;
  List<_Msg> _msgs = [];
  bool _typing = false;
  String _raw = '';

  @override
  void initState() {
    super.initState();
    MemeBank.load();
    _load(scroll: true);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool scroll = false}) async {
    try {
      final raw = await Native.chat();
      if (!mounted || raw == _raw) return;
      _raw = raw;
      final msgs = <_Msg>[];
      for (final line in raw.split('\n')) {
        final p = line.split('\t');
        if (p.length < 3) continue;
        msgs.add(_Msg(int.tryParse(p[0]) ?? 0, p[1], p.sublist(2).join(' ')));
      }
      setState(() => _msgs = msgs);
      if (msgs.isEmpty) await _intro();
      _toBottom();
    } catch (_) {}
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _intro() async {
    for (final l in chatIntro) {
      await Native.addChat('doomy', l);
    }
    _raw = '';
    await _load();
  }

  Future<void> _doomyTypes(List<String> lines) async {
    for (final l in lines) {
      setState(() => _typing = true);
      _toBottom();
      await Future<void>.delayed(const Duration(milliseconds: 650));
      await Native.addChat('doomy', l);
      _raw = '';
      await _load();
    }
    if (mounted) setState(() => _typing = false);
  }

  Future<void> _reply(String q) async {
    if (_typing) return;
    await Native.addChat('you', q);
    _raw = '';
    await _load();

    final hist = await Native.history();
    final time = await Native.timeHistory();
    final s = await Native.settings();
    final key = dateKey(DateTime.now());
    final today = hist[key] ?? <String, int>{};
    final total = sumTracked(today, s);
    final secs = sumTracked(time[key] ?? <String, int>{}, s);
    final noun = trackedNoun(s);
    var week = 0;
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      week += sumTracked(
          hist[dateKey(DateTime(now.year, now.month, now.day - i))] ?? <String, int>{}, s);
    }

    switch (q) {
      case 'how bad is it?':
        await _doomyTypes(howBad(total, noun, fmtDuration(secs), week, tickTarget(today, s)));
      case 'roast me':
        await _doomyTypes(roast(total, noun, secs ~/ 60));
      case 'send a meme':
        final img = MemeBank.randomAny(_rnd);
        final cap = 'ME AFTER $total ${noun.toUpperCase()}';
        await _doomyTypes(['[meme]${img ?? ''}|$cap|${pick(punchlines)}']);
      default:
        await _doomyTypes(pick(stopReplies));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: DoomyHeader(expr: 'chill', when: 'active now'),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            itemCount: _msgs.length + (_typing ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _msgs.length) return _typingBubble();
              final m = _msgs[i];
              final firstOfGroup = i == 0 || _msgs[i - 1].who != m.who;
              final lastOfGroup = i == _msgs.length - 1 || _msgs[i + 1].who != m.who;
              return _bubble(m, firstOfGroup, lastOfGroup);
            },
          ),
        ),
        const Divider(),
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              for (final q in quickReplies)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: _typing ? null : () => _reply(q),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(q),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const DoomyAvatar('smug', size: 30),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration:
                BoxDecoration(color: Palette.bubble, borderRadius: BorderRadius.circular(20)),
            child: const Text('typing...', style: Txt.small),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m, bool first, bool last) {
    final mine = m.who == 'you';
    final top = first ? 10.0 : 2.0;
    Widget content;
    if (m.text.startsWith('[meme]')) {
      final parts = m.text.substring(6).split('|');
      final img = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null;
      content = SizedBox(
        width: 240,
        child: MemeCard(
          image: img,
          top: parts.length > 1 ? parts[1] : '',
          bottom: parts.length > 2 ? parts[2] : '',
          captionSize: 22,
        ),
      );
    } else if (m.text.startsWith('[ad] ')) {
      content = Container(
        constraints: const BoxConstraints(maxWidth: 270),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration:
                  BoxDecoration(color: Palette.adYellow, borderRadius: BorderRadius.circular(5)),
              child: const Text('Ad',
                  style: TextStyle(
                      fontFamily: 'Figtree',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.black)),
            ),
            const SizedBox(height: 6),
            Text(m.text.substring(5), style: Txt.body.copyWith(fontSize: 15)),
          ],
        ),
      );
    } else {
      final loud = m.text == m.text.toUpperCase() && m.text.contains(RegExp('[A-Z]'));
      content = Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? Palette.blue : Palette.bubble,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          m.text,
          style: loud ? Txt.meme.copyWith(fontSize: 26) : Txt.body.copyWith(color: Colors.white),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) SizedBox(width: 38, child: last ? const DoomyAvatar('chill', size: 30) : null),
          Flexible(child: content),
        ],
      ),
    );
  }
}
