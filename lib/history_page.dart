import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'apps.dart';
import 'native.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Map<String, Map<String, int>> _hist = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await Native.history();
      if (!mounted) return;
      setState(() => _hist = h);
    } catch (_) {}
  }

  String _csv() {
    final dates = _hist.keys.toList()..sort();
    final names = reelApps.map((a) => a.key).join(',');
    final b = StringBuffer('date,$names,total\n');
    for (final d in dates) {
      final m = _hist[d] ?? <String, int>{};
      final cols = reelApps.map((a) => (m[a.key] ?? 0).toString()).join(',');
      b.writeln('$d,$cols,${sumCounts(m)}');
    }
    return b.toString();
  }

  Future<void> _export() async {
    await Clipboard.setData(ClipboardData(text: _csv()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copied. Paste it anywhere.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List<DateTime>.generate(
      14,
      (i) => DateTime(now.year, now.month, now.day - i),
    );

    var maxTotal = 1;
    var weekSum = 0;
    for (var i = 0; i < days.length; i++) {
      final t = sumCounts(_hist[dateKey(days[i])] ?? <String, int>{});
      if (t > maxTotal) maxTotal = t;
      if (i < 7) weekSum += t;
    }
    var allTime = 0;
    for (final m in _hist.values) {
      allTime += sumCounts(m);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('History', style: Theme.of(context).textTheme.headlineSmall),
            TextButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.copy),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('${(weekSum / 7).toStringAsFixed(1)}', 'per day (7d)'),
                _stat('$weekSum', 'last 7 days'),
                _stat('$allTime', 'all time'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            for (final a in reelApps)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, color: a.color),
                  const SizedBox(width: 4),
                  Text(a.label.split(' ').first),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final d in days)
          _dayRow(d, _hist[dateKey(d)] ?? <String, int>{}, maxTotal),
      ],
    );
  }

  Widget _stat(String big, String small) {
    return Column(
      children: [
        Text(
          big,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(small, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _dayRow(DateTime d, Map<String, int> counts, int maxTotal) {
    final total = sumCounts(counts);
    final label = '${weekdayNames[d.weekday - 1]} ${d.day}/${d.month}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final bars = <Widget>[];
                for (final a in reelApps) {
                  final n = counts[a.key] ?? 0;
                  if (n > 0) {
                    bars.add(
                      Container(
                        width: w * (n / maxTotal),
                        height: 14,
                        color: a.color,
                      ),
                    );
                  }
                }
                return Row(children: bars);
              },
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('$total', textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
