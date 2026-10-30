import 'dart:async';

import 'package:flutter/material.dart';

import 'apps.dart';
import 'native.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Timer? _timer;
  bool _enabled = true;
  Map<String, int> _today = {};
  Map<String, int> _settings = {};
  NativeStatus _status = const NativeStatus('', 0, 0);

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
      final hist = await Native.history();
      final st = await Native.settings();
      final status = await Native.status();
      if (!mounted) return;
      setState(() {
        _enabled = en;
        _today = hist[dateKey(DateTime.now())] ?? <String, int>{};
        _settings = st;
        _status = status;
      });
    } catch (_) {
      // ignore, try again on next tick
    }
  }

  String _ago(int ms) {
    final secs = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 1000;
    if (secs < 60) return '${secs < 0 ? 0 : secs}s ago';
    if (secs < 3600) return '${secs ~/ 60} min ago';
    if (secs < 86400) return '${secs ~/ 3600} h ago';
    return '${secs ~/ 86400} days ago';
  }

  String _labelFor(String key) {
    for (final a in reelApps) {
      if (a.key == key) return a.label;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final total = sumCounts(_today);
    final limit = _settings['total'] ?? -1;
    var maxApp = 1;
    for (final a in reelApps) {
      final c = _today[a.key] ?? 0;
      if (c > maxApp) maxApp = c;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final snoozeLeftMin = (_status.snoozeUntil - nowMs) / 60000;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_enabled) _enableCard(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Today'),
                    Text(
                      _enabled ? 'Counting is ON' : 'Counting is OFF',
                      style: TextStyle(
                        color:
                            _enabled ? Colors.greenAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$total',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const Text('reels scrolled'),
                if (limit > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (total / limit).clamp(0.0, 1.0).toDouble(),
                  ),
                  const SizedBox(height: 6),
                  Text('Daily limit: $limit'),
                ],
                if (limit == 0) ...[
                  const SizedBox(height: 12),
                  const Text('Reels are fully blocked'),
                ],
                if (snoozeLeftMin > 0) ...[
                  const SizedBox(height: 8),
                  Text('Snoozed for ${snoozeLeftMin.ceil()} more min'),
                ],
                const SizedBox(height: 8),
                Text(
                  _status.lastTime > 0
                      ? 'Last reel counted: ${_labelFor(_status.lastApp)}, ${_ago(_status.lastTime)}'
                      : 'No reels counted yet',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final a in reelApps) _appRow(a, maxApp),
        const SizedBox(height: 16),
        const Text(
          'Counts reset every midnight. History is saved on this phone forever, free.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _appRow(ReelApp a, int maxApp) {
    final c = _today[a.key] ?? 0;
    final lim = _settings['limit:${a.key}'] ?? -1;
    String right = '$c';
    if (lim > 0) right = '$c / $lim';
    if (lim == 0) right = 'blocked';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(a.label),
              Text(right, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: c / maxApp,
            minHeight: 8,
            color: a.color,
          ),
        ],
      ),
    );
  }

  Widget _enableCard() {
    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.orangeAccent),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Counting is OFF',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Turn on DoomPal in Accessibility settings (look under Downloaded apps or Installed apps). '
              'It only listens to Instagram, YouTube, Facebook and Snapchat, and nothing leaves your phone.',
            ),
            SizedBox(height: 8),
            Text(
              'If the switch is greyed out: tap it once and close the popup, then tap "Switch greyed out?" below, '
              'tap the three dots at the top right, choose "Allow restricted settings", and try again.',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: Native.openAccessibilitySettings,
                  child: Text('Open Accessibility settings'),
                ),
                OutlinedButton(
                  onPressed: Native.openAppInfo,
                  child: Text('Switch greyed out?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
