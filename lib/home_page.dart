import 'dart:async';

import 'package:flutter/material.dart';

import 'apps.dart';
import 'lines.dart';
import 'memes.dart';
import 'native.dart';
import 'pictures_page.dart';
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
  Map<String, int> _today = {};
  Map<String, int> _secs = {};
  Map<String, int> _settings = {};
  NativeStatus _status = const NativeStatus('', 0, 0, 0, 0);
  CoachInfo? _coach;

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
      final coach = await Native.coach();
      await MemeBank.load();
      if (!mounted) return;
      final key = dateKey(DateTime.now());
      setState(() {
        _loaded = true;
        _enabled = en;
        _battery = bat;
        _today = hist[key] ?? <String, int>{};
        _secs = time[key] ?? <String, int>{};
        _settings = st;
        _status = status;
        _coach = coach;
      });
    } catch (_) {}
  }

  ({int count, int limit})? _ticksWithBonus() {
    final t = tickTarget(_today, _settings);
    if (t == null) return null;
    return (count: t.count, limit: t.limit + _status.bonusToday);
  }

  @override
  Widget build(BuildContext context) {
    final total = sumTracked(_today, _settings);
    final secs = sumTracked(_secs, _settings);
    final tracked = reelApps.where((a) => isTracked(a, _settings)).toList();
    final noun = trackedNoun(_settings);
    final ticks = _ticksWithBonus();
    final mood = moodFor(counting: !_loaded || _enabled, total: total, secs: secs, noun: noun, ticks: ticks);
    final eq = equivalents(secs);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final guestLeft = (_status.guestUntil - nowMs) / 60000;
    final coach = _coach;
    final baseTotal = _settings['total'] ?? 50;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            const Text('DOOMPAL', style: Txt.wordmark),
            const Spacer(),
            if (_loaded) StatusDot(on: _enabled),
          ],
        ),
        if (_loaded && (!_enabled || !_battery)) ...[
          const SizedBox(height: 14),
          _setupNote(),
        ],
        const SizedBox(height: 10),
        DoomySays(expr: mood.expr, text: mood.text),
        if (guestLeft > 0) ...[
          const SizedBox(height: 12),
          _banner(
            Icons.badge_outlined,
            'guest pass is on: ${guestLeft.ceil()} min left. nothing counts, nothing blocks.',
            Palette.blue,
          ),
        ],
        const SizedBox(height: 14),
        MemeCard(image: MemeBank.pictureOfTheDay(), top: mood.top, bottom: mood.bottom),
        if (_loaded && MemeBank.pictures.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const PicturesPage()));
                await MemeBank.load();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
              label: const Text('Put your own pictures on these memes'),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${ticks?.count ?? total}', style: Txt.bigNumber),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                ticks == null ? '$noun today' : 'of ${ticks.limit} $noun',
                style: Txt.quiet.copyWith(fontSize: 17),
              ),
            ),
          ],
        ),
        if (ticks != null) ...[
          const SizedBox(height: 10),
          LimitBar(count: ticks.count, limit: ticks.limit),
        ],
        if (coach != null && coach.pct > 0 && baseTotal > 0) ...[
          const SizedBox(height: 10),
          Text(
            'doomy tightened ur limit ${coach.pct}% (u set $baseTotal). he does that when u keep slipping.',
            style: Txt.small.copyWith(color: Palette.adYellow),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          secs >= 60 ? 'about ${fmtDuration(secs)} of your life today.' : 'barely any time lost today.',
          style: Txt.small.copyWith(fontSize: 14),
        ),
        if (eq.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text("in that time u could've had:", style: Txt.small),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final e in eq) Chip2(e)]),
        ],
        const SizedBox(height: 22),
        const Divider(),
        for (final a in tracked) ...[_appLine(a), const Divider()],
        if (_status.snoozesToday > 0) ...[
          const SizedBox(height: 16),
          Text(
            'u begged ${_status.snoozesToday} ${_status.snoozesToday == 1 ? 'time' : 'times'} today '
            'and won ${_status.bonusToday} extra. doomy remembers.',
            style: Txt.small,
          ),
        ],
      ],
    );
  }

  Widget _banner(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Txt.small.copyWith(color: Palette.white, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _appLine(ReelApp a) {
    final c = _today[a.key] ?? 0;
    final lim = effLimit(_settings, 'limit:${a.key}');
    final t = _secs[a.key] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: a.color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(a.label, style: Txt.body)),
          Text('$c', style: Txt.title),
          if (lim > 0) Text(' / ${lim + _status.bonusToday}', style: Txt.small),
          if (lim == 0) const Text('  blocked', style: Txt.small),
          SizedBox(
              width: 70,
              child: Text(t >= 60 ? fmtDuration(t) : '', style: Txt.small, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _setupNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.danger.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              DoomyAvatar('judge', size: 36),
              SizedBox(width: 10),
              Expanded(child: Text('doomy needs 2 things to do his job', style: Txt.title)),
            ],
          ),
          const SizedBox(height: 10),
          _step(_enabled, 'Accessibility on, so I can see ur reels'),
          _step(_battery, 'Battery unrestricted, so Android doesn\'t put me to sleep'),
          if (!_enabled) ...[
            const SizedBox(height: 6),
            const Text(
              'Switch greyed out? Tap "Switch greyed out?", then the three dots at the top right, then "Allow restricted settings".',
              style: Txt.small,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_enabled)
                const FilledButton(
                    onPressed: Native.openAccessibilitySettings, child: Text('Open Accessibility')),
              if (!_enabled)
                const OutlinedButton(onPressed: Native.openAppInfo, child: Text('Switch greyed out?')),
              if (!_battery)
                const OutlinedButton(onPressed: Native.openBatterySettings, child: Text('Battery settings')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step(bool done, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(done ? Icons.check_circle : Icons.cancel,
              size: 18, color: done ? Palette.live : Palette.danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: Txt.body.copyWith(fontSize: 15, color: done ? Palette.muted : Palette.white))),
        ],
      ),
    );
  }
}
