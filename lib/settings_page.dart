import 'package:flutter/material.dart';

import 'apps.dart';
import 'log_page.dart';
import 'native.dart';
import 'theme.dart';
import 'widgets.dart';

// -1 = off, 0 = block completely
const List<int> _limitPresets = [-1, 0, 5, 10, 20, 30, 50, 75, 100, 150, 200];
const List<int> _snoozePresets = [1, 5, 10, 15, 30];
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
      child: Text(text, style: Txt.title.copyWith(color: Palette.sage)),
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
              Text(value, style: Txt.body.copyWith(color: Palette.pollen)),
            ],
            if (trailing != null) ...[const SizedBox(width: 16), trailing],
          ],
        ),
      ),
    );
  }

  Widget _switch(String title, String? subtitle, String key,
      {int fallback = 0}) {
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
            child: const Text('Keep history',
                style: TextStyle(color: Palette.lichen)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Palette.straw),
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
          child: Text('Limits', style: Txt.heading),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Text(
            'When you reach a limit, DoomPal covers the reels screen and offers to take you home. '
            'The rest of the app keeps working.',
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
        _section('Breaking the habit'),
        _choice(
          title: 'Reminder while scrolling',
          subtitle: 'A short message like "10 Shorts today, about 5 min"',
          key: 'nudge',
          fallback: 10,
          presets: _nudgePresets,
          label: (v) => v == 0 ? 'Off' : 'Every $v',
        ),
        _switch('Hard mode',
            'No snoozing. You go straight home when you hit a limit.', 'hard'),
        if (!hard) ...[
          _choice(
            title: 'Snoozes a day',
            subtitle: 'After these, the limit can\'t be skipped',
            key: 'maxSnooze',
            fallback: 2,
            presets: _maxSnoozePresets,
            label: (v) => v < 0 ? 'Unlimited' : '$v',
          ),
          _choice(
            title: 'Each snooze lasts',
            key: 'snooze',
            fallback: 5,
            presets: _snoozePresets,
            label: (v) => '$v min',
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
        _switch('Keep a detection log',
            'Records what DoomPal sees, for fixing detection', 'debug'),
        _row(
          title: 'Open detection log',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LogPage()),
          ),
          trailing: const Icon(Icons.chevron_right, color: Palette.sage),
        ),
        _section('This phone'),
        _row(
          title: 'Battery settings',
          subtitle: 'Choose Unrestricted so Android never stops the counter',
          onTap: Native.openBatterySettings,
          trailing: const Icon(Icons.chevron_right, color: Palette.sage),
        ),
        _row(
          title: 'Delete all history',
          titleColor: Palette.straw,
          onTap: _confirmClear,
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Text(
            'Everything DoomPal records stays on this phone. It has no internet access.',
            style: Txt.small,
          ),
        ),
      ],
    );
  }
}
