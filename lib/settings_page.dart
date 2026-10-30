import 'package:flutter/material.dart';

import 'apps.dart';
import 'log_page.dart';
import 'native.dart';

// -1 = off, 0 = block completely
const List<int> _limitPresets = [-1, 0, 5, 10, 20, 30, 50, 75, 100, 150, 200];
const List<int> _snoozePresets = [1, 5, 10, 15, 30];

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
    if (v == -1) return 'Off';
    if (v == 0) return 'Block completely';
    return '$v reels';
  }

  Widget _limitTile(String title, String key) {
    final current = _s[key] ?? -1;
    final value = _limitPresets.contains(current) ? current : -1;
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<int>(
        value: value,
        items: [
          for (final p in _limitPresets)
            DropdownMenuItem<int>(value: p, child: Text(_limitLabel(p))),
        ],
        onChanged: (v) {
          if (v != null) _set(key, v);
        },
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all history?'),
        content: const Text(
            'This removes every saved daily count. It cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await Native.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final snooze = _s['snooze'] ?? 5;
    final snoozeValue = _snoozePresets.contains(snooze) ? snooze : 5;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child:
              Text('Limits', style: Theme.of(context).textTheme.headlineSmall),
        ),
        _limitTile('Daily total (all apps)', 'total'),
        for (final a in reelApps) _limitTile(a.label, 'limit:${a.key}'),
        const Divider(),
        SwitchListTile(
          title: const Text('Hard mode'),
          subtitle: const Text(
              'No snooze button. Sends you home when the limit is hit.'),
          value: (_s['hard'] ?? 0) == 1,
          onChanged: (v) => _set('hard', v ? 1 : 0),
        ),
        ListTile(
          title: const Text('Snooze length'),
          subtitle: const Text('Extra time the "more minutes" button gives'),
          trailing: DropdownButton<int>(
            value: snoozeValue,
            items: [
              for (final p in _snoozePresets)
                DropdownMenuItem<int>(value: p, child: Text('$p min')),
            ],
            onChanged: (v) {
              if (v != null) _set('snooze', v);
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child:
              Text('Detection', style: Theme.of(context).textTheme.titleMedium),
        ),
        SwitchListTile(
          title: const Text('Count every scroll (lenient)'),
          subtitle: const Text(
            'Use if reels in an app are not being detected. Counts any vertical scroll in the 4 apps, feed included.',
          ),
          value: (_s['lenient'] ?? 0) == 1,
          onChanged: (v) => _set('lenient', v ? 1 : 0),
        ),
        SwitchListTile(
          title: const Text('Detection log'),
          subtitle:
              const Text('Records what DoomPal sees so detection can be tuned'),
          value: (_s['debug'] ?? 0) == 1,
          onChanged: (v) => _set('debug', v ? 1 : 0),
        ),
        ListTile(
          title: const Text('View detection log'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LogPage()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Delete all history'),
          onTap: _confirmClear,
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Phone keeps killing the counter? Open Settings > Apps > DoomPal and set Battery to '
            '"No restrictions" (on Xiaomi/Poco also turn on Autostart). Lock DoomPal in the recents screen too.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
