import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'apps.dart';
import 'native.dart';
import 'theme.dart';
import 'widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _loaded = false;
  Map<String, Map<String, int>> _hist = {};
  Map<String, Map<String, int>> _time = {};
  Map<String, int> _settings = {};

  static const _short = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _weekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await Native.history();
      final t = await Native.timeHistory();
      final s = await Native.settings();
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _hist = h;
        _time = t;
        _settings = s;
      });
    } catch (_) {}
  }

  String _csv() {
    final dates = _hist.keys.toList()..sort();
    final names = reelApps.map((a) => a.key).join(',');
    final b = StringBuffer('date,$names,total,minutes\n');
    for (final d in dates) {
      final m = _hist[d] ?? <String, int>{};
      final cols = reelApps.map((a) => (m[a.key] ?? 0).toString()).join(',');
      final mins = (sumCounts(_time[d] ?? <String, int>{}) / 60).round();
      b.writeln('$d,$cols,${sumCounts(m)},$mins');
    }
    return b.toString();
  }

  Future<void> _export() async {
    await Clipboard.setData(ClipboardData(text: _csv()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('History copied as CSV. Paste it into a sheet or a note.')),
    );
  }

  int _dayLimit() {
    final total = _settings['total'] ?? -1;
    if (total > 0) return total;
    final t = tickTarget(const <String, int>{}, _settings);
    return t?.limit ?? -1;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List<DateTime>.generate(
        14, (i) => DateTime(now.year, now.month, now.day - i));
    final noun = trackedNoun(_settings);
    final limit = _dayLimit();

    var weekSum = 0;
    var weekSecs = 0;
    var maxTotal = 1;
    for (var i = 0; i < days.length; i++) {
      final key = dateKey(days[i]);
      final t = sumTracked(_hist[key] ?? <String, int>{}, _settings);
      if (t > maxTotal) maxTotal = t;
      if (i < 7) {
        weekSum += t;
        weekSecs += sumTracked(_time[key] ?? <String, int>{}, _settings);
      }
    }
    var allTime = 0;
    for (final m in _hist.values) {
      allTime += sumTracked(m, _settings);
    }

    final week = [
      for (var i = 6; i >= 0; i--)
        DayBar(
          _short[days[i].weekday - 1],
          sumTracked(_hist[dateKey(days[i])] ?? <String, int>{}, _settings),
          i == 0,
        ),
    ];

    final children = <Widget>[
      const Text('History', style: Txt.heading),
      const SizedBox(height: 10),
    ];

    if (_loaded && allTime == 0) {
      children.addAll([
        Text(
          'Nothing here yet. Your history fills in from the first $noun DoomPal counts.',
          style: Txt.quiet,
        ),
      ]);
    } else {
      final perDay = (weekSum / 7).round();
      children.addAll([
        Text(
          weekSum == 0
              ? 'No $noun in the last 7 days.'
              : 'In the last 7 days you scrolled $weekSum $noun, about ${fmtDuration(weekSecs)}. '
                  'That is around $perDay a day.',
          style: Txt.body,
        ),
        const SizedBox(height: 4),
        Text('$allTime since you started counting.', style: Txt.small),
        const SizedBox(height: 28),
        WeekChart(days: week, limit: limit),
        if (limit > 0) ...[
          const SizedBox(height: 8),
          Text('The dashed line is your daily limit of $limit.',
              style: Txt.small),
        ],
        const SizedBox(height: 32),
        const Text('Last two weeks', style: Txt.title),
        const SizedBox(height: 8),
        const Divider(),
        for (final d in days) ...[
          _dayRow(d, maxTotal, limit),
          const Divider(),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy history as CSV'),
          ),
        ),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: children,
    );
  }

  Widget _dayRow(DateTime d, int maxTotal, int limit) {
    final key = dateKey(d);
    final counts = _hist[key] ?? <String, int>{};
    final total = sumTracked(counts, _settings);
    final t = sumTracked(_time[key] ?? <String, int>{}, _settings);
    final over = limit > 0 && total > limit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '${_weekdayNames[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}',
              style: Txt.body,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final bars = <Widget>[];
                for (final a in reelApps) {
                  if (!isTracked(a, _settings)) continue;
                  final n = counts[a.key] ?? 0;
                  if (n > 0) {
                    bars.add(Container(
                      width: c.maxWidth * (n / maxTotal),
                      height: 6,
                      decoration: BoxDecoration(
                        color: a.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ));
                  }
                }
                return Row(children: bars);
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Text(
              '$total',
              style: Txt.number.copyWith(
                fontSize: 17,
                color: over ? Palette.straw : Palette.lichen,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(
            width: 70,
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
}
