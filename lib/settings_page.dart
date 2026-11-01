import 'package:flutter/material.dart';

import 'apps.dart';
import 'log_page.dart';
import 'memes.dart';
import 'native.dart';
import 'pictures_page.dart';
import 'terms_page.dart';
import 'theme.dart';
import 'widgets.dart';

// -1 = off, 0 = block completely
const List<int> _limitPresets = [-1, 0, 5, 10, 20, 30, 50, 75, 100, 150, 200];
const List<int> _maxSnoozePresets = [-1, 0, 1, 2, 3, 5];
const List<int> _nudgePresets = [0, 3, 5, 10, 20];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, int> _s = {};
  List<PendingChange> _pending = [];
  CoachInfo? _coach;
  NativeStatus _status = const NativeStatus('', 0, 0, 0, 0);
  int _pics = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Native.settings();
      final pend = await Native.pending();
      final coach = await Native.coach();
      final status = await Native.status();
      final pics = await Native.listPictures();
      MemeBank.pictures = pics;
      if (!mounted) return;
      setState(() {
        _s = s;
        _pending = pend;
        _coach = coach;
        _status = status;
        _pics = pics.length;
      });
    } catch (_) {}
  }

  void _say(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _hoursText(int h) =>
      h == 1 ? '1 hour' : (h % 24 == 0 && h >= 24 ? '${h ~/ 24} ${h == 24 ? 'day' : 'days'}' : '$h hours');

  /// Strict changes happen at once. Loosening ones are queued by the lock and show up in the banner.
  Future<void> _set(String key, int value) async {
    try {
      final r = await Native.setSetting(key, value);
      if (r.queued && mounted) {
        _say(
            'nope, not right now. that loosens a rule, so it waits ${_hoursText(r.hours)}. cancel it up top anytime.');
      }
    } catch (_) {}
    await _load();
  }

  // ---- friendly words for the waiting-changes banner
  String _name(String key) {
    if (key == 'total') return 'Daily total limit';
    if (key.startsWith('limit:')) {
      final k = key.substring(6);
      for (final a in reelApps) {
        if (a.key == k) return '${a.label} limit';
      }
    }
    if (key.startsWith('track:')) {
      final k = key.substring(6);
      for (final a in reelApps) {
        if (a.key == k) return 'Tracking ${a.label}';
      }
    }
    const names = {
      'hard': 'Hard mode',
      'quiet': 'Quiet hours',
      'quietStart': 'Quiet hours start',
      'quietEnd': 'Quiet hours end',
      'lock': 'The lock',
      'lockHours': 'Lock cooldown',
      'coach': 'Doomy coach',
      'gate': 'Check-ins',
      'gateEvery': 'Check-in spacing',
      'maxSnooze': 'Begs a day',
      'begReels': 'Reels per beg',
      'adSecs': 'Ad length',
      'guest': 'Guest pass',
      'guestMins': 'Guest pass length',
      'guestPerDay': 'Guest passes a day',
      'lenient': 'Count every scroll',
    };
    return names[key] ?? key;
  }

  String _valueText(String key, int v) {
    if (key == 'total' || key.startsWith('limit:'))
      return v < 0 ? 'no limit' : (v == 0 ? 'blocked' : '$v a day');
    if (key == 'maxSnooze') return v < 0 ? 'unlimited' : '$v';
    if (key == 'quietStart' || key == 'quietEnd') return fmtHour(v);
    if (key == 'lockHours') return _hoursText(v);
    if (key == 'adSecs') return '$v sec';
    if (key == 'guestMins' || key == 'gateEvery') return '$v min';
    if (key == 'begReels') return '$v more';
    if (key == 'guestPerDay') return '$v';
    return v == 1 ? 'on' : 'off';
  }

  String _in(int atMs) {
    final left = Duration(milliseconds: atMs - DateTime.now().millisecondsSinceEpoch);
    if (left.inMinutes < 1) return 'any moment now';
    if (left.inHours < 1) return 'in ${left.inMinutes} min';
    final m = left.inMinutes % 60;
    return 'in ${left.inHours} h${m > 0 ? ' $m min' : ''}';
  }

  // ---- building blocks
  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 6),
      child: Text(text, style: Txt.title.copyWith(color: Palette.muted)),
    );
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 8),
      child: Text(text, style: Txt.small),
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

  String _limitLabel(int v) {
    if (v == -1) return 'No limit';
    if (v == 0) return 'Blocked all day';
    return '$v a day';
  }

  Widget _limitChoice(String title, String key, int fallback) {
    final base = _s[key] ?? fallback;
    final eff = effLimit(_s, key);
    final tightened = base > 0 && eff > 0 && eff < base;
    return _choice(
      title: title,
      subtitle: tightened ? 'doomy tightened this to $eff for now' : null,
      key: key,
      fallback: fallback,
      presets: _limitPresets,
      label: _limitLabel,
    );
  }

  Widget _pendingBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.adYellow.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              DoomyAvatar('smug', size: 40),
              SizedBox(width: 10),
              Expanded(child: Text('these are waiting out the lock', style: Txt.title)),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in _pending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_name(p.key)} to ${_valueText(p.key, p.value)}\n${_in(p.at)}',
                      style: Txt.body.copyWith(fontSize: 15),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Native.cancelPending(p.key);
                      await _load();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _coachCard() {
    final c = _coach;
    if (c == null) return const SizedBox.shrink();
    final color = c.mood == 'tight' ? Palette.danger : (c.mood == 'relax' ? Palette.live : Palette.muted);
    final riskText = c.risk.isEmpty ? 'none yet' : c.risk.map(fmtHour).join(', ');
    final learned = c.trained
        ? 'knows how u scroll (${c.swipes} swipes)'
        : 'still learning how u scroll (${c.swipes} of ${c.minTrain} swipes)';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.note, style: Txt.body.copyWith(color: color, fontSize: 15)),
          const SizedBox(height: 10),
          Text('Doomy $learned.', style: Txt.small),
          if (c.pauseSecs > 0)
            Text('Usual pause between reels: ${c.pauseSecs.toStringAsFixed(1)} sec.', style: Txt.small),
          Text('Danger hours: $riskText.', style: Txt.small),
          if (c.pct > 0 || c.adExtra > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Right now: limits ${c.pct}% stricter, ads ${c.adExtra} sec longer${c.begCut > 0 ? ', one less beg a day' : ''}.',
              style: Txt.small,
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'All of this is worked out on this phone from simple counting. It never goes looser than the limit you set.',
            style: Txt.small,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear() async {
    final lockOn = (_s['lock'] ?? 1) == 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete history?'),
        content: Text(
          lockOn
              ? 'Every earlier day and your chat with Doomy will be removed. Today\'s numbers stay, because the '
                  'lock is on and this can\'t be used to reset a limit.'
              : 'Every saved count and time, and your chat with Doomy, will be removed from this phone.',
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
      _say('History deleted.');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final quietOn = (_s['quiet'] ?? 1) == 1;
    final hard = (_s['hard'] ?? 0) == 1;
    final lockOn = (_s['lock'] ?? 1) == 1;
    final lockHours = _s['lockHours'] ?? 24;
    final guestOn = (_s['guest'] ?? 1) == 1;
    final hours = List<int>.generate(24, (i) => i);

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
            'Set the rules. Doomy enforces them, and the lock keeps weak-moment you from undoing them.',
            style: Txt.quiet,
          ),
        ),
        if (_pending.isNotEmpty) _pendingBanner(),
        _section('The lock'),
        _switch(
          'Lock my rules',
          lockOn
              ? 'Stricter changes happen now. Looser ones wait ${_hoursText(lockHours)}.'
              : 'Off: every change happens instantly.',
          'lock',
          fallback: 1,
        ),
        _choice(
          title: 'Cooldown',
          subtitle: 'How long a looser rule waits before it applies',
          key: 'lockHours',
          fallback: 24,
          presets: const [1, 6, 24, 72],
          label: _hoursText,
        ),
        if ((_s['setupMinsLeft'] ?? 0) > 0)
          _note(
              'Setup window: for ${_s['setupMinsLeft']} more min, every change is instant, so you can tune things. Then the lock kicks in.'),
        _note(
          'Doomy can\'t stop you turning off Accessibility or uninstalling. If you really want this to hold, '
          'ask someone you trust to set the lock for you.',
        ),
        _section('Daily limits'),
        _limitChoice('All tracked apps together', 'total', 50),
        for (final a in reelApps)
          if (isTracked(a, _s)) _limitChoice(a.label, 'limit:${a.key}', -1),
        _section('Doomy coach'),
        _switch(
          'Let Doomy adapt',
          'Learns from your habits on this phone. Tightens when you slip, eases back when you don\'t.',
          'coach',
          fallback: 1,
        ),
        _coachCard(),
        _section('Guest pass'),
        _switch(
          'Allow guest passes',
          'For someone else, like your mom looking up a recipe',
          'guest',
          fallback: 1,
        ),
        if (guestOn) ...[
          _choice(
            title: 'Pass length',
            key: 'guestMins',
            fallback: 15,
            presets: const [10, 15, 30],
            label: (v) => '$v min',
          ),
          _choice(
            title: 'Passes a day',
            subtitle: _status.guestUsesToday > 0 ? 'used ${_status.guestUsesToday} today' : null,
            key: 'guestPerDay',
            fallback: 1,
            presets: const [1, 2],
            label: (v) => '$v',
          ),
        ],
        _note(
          'A pass works in two steps. First a fingerprint saved on this phone. Android can\'t tell whose finger it is, '
          'so only add someone\'s fingerprint in Android settings if you\'re fine with them unlocking the phone too. '
          'Then Doomy watches the first 10 swipes. If they scroll like you, the pass is cancelled and those swipes '
          'count. That check is a rough guess: it can miss someone who scrolls differently on purpose, and it can '
          'cancel a real guest who happens to scroll like you. Nothing counts or is learned during a pass.',
        ),
        _section('Doomy check-ins'),
        _switch('Live counter', 'A bubble with ur count while u scroll', 'counter', fallback: 1),
        _switch('Check on me when I open reels', '"boi boi, no reels? why u scrolling"', 'gate', fallback: 1),
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
          fallback: 5,
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
            fallback: 1,
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
        _section('Your health'),
        _switch(
          'Eye breaks',
          'After 20 minutes of scrolling, Doomy tells you to look far away for 20 seconds',
          'eyeBreak',
          fallback: 1,
        ),
        _switch('Quiet hours', 'Blocks reels completely at night, so sleep wins', 'quiet', fallback: 1),
        if (quietOn) ...[
          _choice(title: 'Starts at', key: 'quietStart', fallback: 23, presets: hours, label: fmtHour),
          _choice(title: 'Ends at', key: 'quietEnd', fallback: 6, presets: hours, label: fmtHour),
        ],
        _section('Your pictures'),
        _row(
          title: 'Use my own pictures',
          subtitle: 'Pick photos and stickers. Doomy captions them and uses them by himself.',
          value: _pics == 0 ? 'None yet' : '$_pics',
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PicturesPage()));
            await _load();
          },
        ),
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
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LogPage())),
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
          title: 'Terms and privacy',
          subtitle: 'Everything stays on this phone',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TermsPage(readOnly: true)),
          ),
          trailing: const Icon(Icons.chevron_right, color: Palette.muted),
        ),
        _row(title: 'Delete history', titleColor: Palette.danger, onTap: _confirmClear),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Text(
            'Everything Doomy sees and learns stays on this phone. He has no internet access, and the ads are jokes, not real ads.',
            style: Txt.small,
          ),
        ),
      ],
    );
  }
}
