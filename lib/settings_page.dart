import 'package:flutter/material.dart';

import 'apps.dart';
import 'log_page.dart';
import 'native.dart';
import 'theme.dart';
import 'widgets.dart';

// -1 = off, 0 = block completely
const List<int> _limitPresets = [-1, 0, 5, 10, 20, 30, 50, 75, 100, 150, 200];
const List<int> _maxSnoozePresets = [-1, 1, 2, 3, 5];
const List<int> _nudgePresets = [0, 5, 10, 20, 30];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, int> _s = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Native.settings();
      if (!mounted) return;
      setState(() => _s = s);
    } catch (_) {}
  }

  Future<void> _set(String key, int value) async {
    setState(() => _s = {..._s, key: value});
    await Native.setSetting(key, value);
  }

  String _limitLabel(int v) {
    if (v == -1) return 'No limit';
    if (v == 0) return 'Blocked all day';
    return '$v a day';
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 6),
      child: Text(text, style: Txt.title.copyWith(color: Palette.muted)),
    );
  }

  Widget _row({
    required String title,
    String? subtitle,
    String? value,
    Color? titleColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Txt.body.copyWith(color: titleColor)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: Txt.small),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 16),
              Text(value, style: Txt.body.copyWith(color: Palette.doomy)),
            ],
            if (trailing != null) ...[const SizedBox(width: 16), trailing],
          ],
        ),
      ),
    );
  }

  Widget _switch(String title, String? subtitle, String key, {int fallback = 0}) {
    final on = (_s[key] ?? fallback) == 1;
    return _row(
      title: title,
      subtitle: subtitle,
      onTap: () => _set(key, on ? 0 : 1),
      trailing: Switch(value: on, onChanged: (v) => _set(key, v ? 1 : 0)),
    );
  }

  Widget _choice({
    required String title,
    String? subtitle,
    String? note,
    required String key,
    required int fallback,
    required List<int> presets,
    required String Function(int) label,
  }) {
    final current = _s[key] ?? fallback;
    final value = presets.contains(current) ? current : fallback;
    return _row(
      title: title,
      subtitle: subtitle,
      value: label(value),
      onTap: () async {
        final picked = await pickChoice<int>(
          context,
          title: title,
          note: note,
          choices: [for (final p in presets) Choice(p, label(p))],
          current: value,
        );
        if (picked != null) await _set(key, picked);
      },
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all history?'),
        content: const Text(
          'Every saved count and time will be removed from this phone. Your limits stay as they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep history', style: TextStyle(color: Palette.white)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Palette.danger),
            child: const Text('Delete history'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Native.clearHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quietOn = (_s['quiet'] ?? 0) == 1;
    final hard = (_s['hard'] ?? 0) == 1;

    return ListView(
      padding: const EdgeInsets.only(top: 20, bottom: 32),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('RULES', style: Txt.wordmark),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Text(
            'Set the rules. Doomy enforces them. When you hit a limit he covers the reels screen, '
            'and the rest of the app keeps working.',
            style: Txt.quiet,
          ),
        ),
        _section('Daily limits'),
        _choice(
          title: 'All tracked apps together',
          key: 'total',
          fallback: -1,
          presets: _limitPresets,
          label: _limitLabel,
        ),
        for (final a in reelApps)
          if (isTracked(a, _s))
            _choice(
              title: a.label,
              key: 'limit:${a.key}',
              fallback: -1,
              presets: _limitPresets,
              label: _limitLabel,
            ),
        _section('Doomy'),
        _switch('Live counter', 'A small bubble with ur count while u scroll', 'counter',
            fallback: 1),
        _switch('Check on me when I open reels', '"boi boi, no reels? why u scrolling"', 'gate',
            fallback: 1),
        if ((_s['gate'] ?? 1) == 1)
          _choice(
            title: 'Check again after',
            key: 'gateEvery',
            fallback: 15,
            presets: const [5, 10, 15, 30, 60],
            label: (v) => '$v min',
          ),
        _choice(
          title: 'Doomy comments every',
          subtitle: 'Little messages like "20 already?? blink twice"',
          key: 'nudge',
          fallback: 10,
          presets: _nudgePresets,
          label: (v) => v == 0 ? 'Never' : '$v reels',
        ),
        _section('Begging'),
        _switch('Hard mode', 'No begging. You go straight home at the limit.', 'hard'),
        if (!hard) ...[
          _choice(
            title: 'Begs a day',
            subtitle: 'After these, Doomy stops listening',
            key: 'maxSnooze',
            fallback: 2,
            presets: _maxSnoozePresets,
            label: (v) => v < 0 ? 'Unlimited' : '$v',
          ),
          _choice(
            title: 'Reels per beg',
            key: 'begReels',
            fallback: 5,
            presets: const [3, 5, 10],
            label: (v) => '$v more',
          ),
          _choice(
            title: 'Ad length',
            subtitle: 'Gets longer with every beg',
            key: 'adSecs',
            fallback: 10,
            presets: const [5, 10, 15, 20, 30],
            label: (v) => '$v sec',
          ),
        ],
        _section('Bedtime'),
        _switch('Quiet hours', 'Blocks reels completely at night', 'quiet'),
        if (quietOn) ...[
          _choice(
            title: 'Starts at',
            key: 'quietStart',
            fallback: 23,
            presets: List<int>.generate(24, (i) => i),
            label: fmtHour,
          ),
          _choice(
            title: 'Ends at',
            key: 'quietEnd',
            fallback: 6,
            presets: List<int>.generate(24, (i) => i),
            label: fmtHour,
          ),
        ],
        _section('Apps'),
        for (final a in reelApps)
          _row(
            title: a.label,
            onTap: () => _set('track:${a.key}', isTracked(a, _s) ? 0 : 1),
            trailing: Switch(
              value: isTracked(a, _s),
              onChanged: (v) => _set('track:${a.key}', v ? 1 : 0),
            ),
          ),
        _section('Detection'),
        _switch(
          'Count every scroll',
          'Only if reels in an app aren\'t being counted. Counts the feed too.',
          'lenient',
        ),
        _switch('Keep a detection log', 'Records what DoomPal sees, for fixing detection', 'debug'),
        _row(
          title: 'Open detection log',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LogPage()),
          ),
          trailing: const Icon(Icons.chevron_right, color: Palette.muted),
        ),
        _section('This phone'),
        _row(
          title: 'Battery settings',
          subtitle: 'Choose Unrestricted so Android never stops the counter',
          onTap: Native.openBatterySettings,
          trailing: const Icon(Icons.chevron_right, color: Palette.muted),
        ),
        _row(
          title: 'Delete all history',
          titleColor: Palette.danger,
          onTap: _confirmClear,
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Text(
            'Everything Doomy sees stays on this phone. He has no internet access, and the ads are jokes, not real ads.',
            style: Txt.small,
          ),
        ),
      ],
    );
  }
}
