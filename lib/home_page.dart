import 'dart:async';

import 'package:flutter/material.dart';

import 'apps.dart';
import 'native.dart';
import 'sprout.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Timer? _timer;
  bool _loaded = false;
  bool _enabled = true;
  bool _battery = true;
  Map<String, Map<String, int>> _hist = {};
  Map<String, int> _today = {};
  Map<String, int> _secs = {};
  Map<String, int> _settings = {};
  NativeStatus _status = const NativeStatus('', 0, 0, 0);

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final en = await Native.isServiceEnabled();
      final bat = await Native.batteryUnrestricted();
      final hist = await Native.history();
      final time = await Native.timeHistory();
      final st = await Native.settings();
      final status = await Native.status();
      if (!mounted) return;
      final key = dateKey(DateTime.now());
      setState(() {
        _loaded = true;
        _enabled = en;
        _battery = bat;
        _hist = hist;
        _today = hist[key] ?? <String, int>{};
        _secs = time[key] ?? <String, int>{};
        _settings = st;
        _status = status;
      });
    } catch (_) {
      // try again on the next tick
    }
  }

  String _dateLine() {
    final d = DateTime.now();
    return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  String _ago(int ms) {
    final secs = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 1000;
    if (secs < 60) return 'just now';
    if (secs < 3600) {
      final m = secs ~/ 60;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (secs < 86400) {
      final h = secs ~/ 3600;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    return 'on an earlier day';
  }

  String _plantLine(double health, bool hasLimit) {
    if (!hasLimit && health > 0.66)
      return 'Your sprout is waiting for a limit.';
    if (health > 0.66) return 'Your sprout is doing well.';
    if (health > 0.33) return 'Your sprout is getting thirsty.';
    if (health > 0) return 'Your sprout is drooping.';
    return 'Your sprout has wilted for today.';
  }

  String _plantHint(double health, bool hasLimit, int? streak,
      ({int count, int limit})? ticks) {
    if (!hasLimit) {
      return 'Set a daily limit and it grows a new leaf for every day you stay within it.';
    }
    if (health <= 0)
      return 'It recovers at midnight. Your streak starts again tomorrow.';
    final parts = <String>[];
    if (ticks != null) {
      final left = ticks.limit - ticks.count;
      if (left > 0) parts.add('$left more before your limit.');
    }
    final s = streak ?? 0;
    if (s < 7) {
      final d = 7 - s;
      parts.add(
          'Stay within your limit for $d more ${d == 1 ? 'day' : 'days'} and it flowers.');
    } else {
      parts.add('It has flowered. Keep it that way.');
    }
    return parts.join(' ');
  }

  String _footer(int? streak) {
    final parts = <String>[];
    if (streak != null && streak > 0) {
      parts.add(
          '${streak == 1 ? '1 day' : '$streak days'} in a row within your limit.');
    }
    if (_status.lastTime > 0) {
      parts.add('Last counted ${_ago(_status.lastTime)}.');
    }
    final snoozeLeft =
        (_status.snoozeUntil - DateTime.now().millisecondsSinceEpoch) / 60000;
    if (snoozeLeft > 0) {
      parts.add('Snoozed for ${snoozeLeft.ceil()} more min.');
    } else if (_status.snoozesToday > 0) {
      parts.add(
          '${_status.snoozesToday} ${_status.snoozesToday == 1 ? 'snooze' : 'snoozes'} used today.');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final total = sumTracked(_today, _settings);
    final secs = sumTracked(_secs, _settings);
    final tracked = reelApps.where((a) => isTracked(a, _settings)).toList();
    final health = plantHealth(_today, _settings);
    final streak = streakDays(_hist, _settings);
    final hasLimit = streak != null || (_settings['total'] ?? -1) == 0;
    final ticks = tickTarget(_today, _settings);
    final noun = trackedNoun(_settings);
    final footer = _footer(streak);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_dateLine(), style: Txt.quiet),
            if (_loaded)
              StatusDot(
                  on: _enabled, onText: 'Counting', offText: 'Not counting'),
          ],
        ),
        if (_loaded && (!_enabled || !_battery)) ...[
          const SizedBox(height: 16),
          _setupNote(),
        ],
        const SizedBox(height: 28),
        _shelf(total, health, streak ?? 0, _plantLine(health, hasLimit)),
        const SizedBox(height: 16),
        Text(
          secs > 0
              ? '$noun today, about ${fmtDuration(secs)}.'
              : '$noun today.',
          style: Txt.body,
        ),
        if (ticks != null) ...[
          const SizedBox(height: 18),
          TickRow(count: ticks.count, limit: ticks.limit),
          const SizedBox(height: 8),
          Text('${ticks.count} of ${ticks.limit}', style: Txt.small),
        ],
        const SizedBox(height: 26),
        Text(_plantLine(health, hasLimit), style: Txt.title),
        const SizedBox(height: 4),
        Text(_plantHint(health, hasLimit, streak, ticks), style: Txt.quiet),
        const SizedBox(height: 28),
        const Divider(),
        for (final a in tracked) ...[
          _appLine(a),
          const Divider(),
        ],
        if (footer.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(footer, style: Txt.small),
        ],
      ],
    );
  }

  /// The count and the sprout standing on one shelf line, like things on a windowsill.
  Widget _shelf(int total, double health, int stage, String label) {
    final digits = '$total'.length;
    final fontSize = digits <= 2 ? 112.0 : (digits == 3 ? 92.0 : 72.0);
    final style = Txt.display.copyWith(fontSize: fontSize);
    final tp = TextPainter(
      text: TextSpan(text: '$total', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final descent =
        tp.height - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final plantW = digits <= 2 ? 190.0 : 168.0;
    final plantH = Sprout.heightFor(plantW);
    return SizedBox(
      height: plantH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(height: 1, child: ColoredBox(color: Palette.vein)),
          ),
          Positioned(
            right: -18,
            bottom: -Sprout.potBaseInset(plantW),
            child: Sprout(
                health: health,
                stage: stage,
                width: plantW,
                semanticLabel: label),
          ),
          Positioned(
            left: -5,
            bottom: -descent,
            child: Text('$total', style: style),
          ),
        ],
      ),
    );
  }

  Widget _appLine(ReelApp a) {
    final c = _today[a.key] ?? 0;
    final lim = _settings['limit:${a.key}'] ?? -1;
    final t = _secs[a.key] ?? 0;
    final limitText = lim == 0 ? 'blocked' : (lim > 0 ? 'of $lim' : '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: a.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(a.label, style: Txt.body)),
          Text('$c', style: Txt.number),
          if (limitText.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(limitText, style: Txt.small),
          ],
          SizedBox(
            width: 76,
            child: Text(
              t > 0 ? fmtDuration(t) : '',
              style: Txt.small,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(bool done, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: done ? const Color(0xFF8CC97E) : Palette.sage,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Txt.body
                  .copyWith(color: done ? Palette.sage : Palette.lichen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupNote() {
    final todo = (_enabled ? 0 : 1) + (_battery ? 0 : 1);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Palette.bark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            todo == 1
                ? 'One thing left to set up'
                : 'Two things left to set up',
            style: Txt.title,
          ),
          const SizedBox(height: 10),
          _step(_enabled, 'Turn on DoomPal in Accessibility, so it can count.'),
          _step(_battery,
              'Let it run without battery limits, so Android doesn\'t stop it.'),
          if (!_enabled) ...[
            const SizedBox(height: 8),
            const Text(
              'If the switch is greyed out, tap "Switch greyed out?", then the three dots at the top right, '
              'then "Allow restricted settings".',
              style: Txt.small,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!_enabled)
                const FilledButton(
                  onPressed: Native.openAccessibilitySettings,
                  child: Text('Open Accessibility'),
                ),
              if (!_enabled)
                const OutlinedButton(
                  onPressed: Native.openAppInfo,
                  child: Text('Switch greyed out?'),
                ),
              if (!_battery)
                FilledButton(
                  onPressed: Native.openBatterySettings,
                  style: _enabled
                      ? null
                      : OutlinedButton.styleFrom(
                          foregroundColor: Palette.lichen,
                          side: const BorderSide(color: Palette.vein),
                          backgroundColor: Colors.transparent,
                        ),
                  child: const Text('Battery settings'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
