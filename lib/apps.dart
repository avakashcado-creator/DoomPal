import 'package:flutter/material.dart';

/// Keys must match android_overlay/kotlin/Targets.kt
class ReelApp {
  final String key;
  final String label;
  final String noun;
  final Color color;
  final bool defaultOn;
  const ReelApp(this.key, this.label, this.noun, this.color, this.defaultOn);
}

const List<ReelApp> reelApps = [
  ReelApp('youtube', 'YouTube Shorts', 'Shorts', Color(0xFFFF5C5C), true),
  ReelApp('instagram', 'Instagram Reels', 'reels', Color(0xFFE1306C), true),
  ReelApp('facebook', 'Facebook Reels', 'reels', Color(0xFF1877F2), false),
  ReelApp('snapchat', 'Snapchat Spotlight', 'Spotlights', Color(0xFFFFC400), false),
];

const List<String> weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String dateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

int sumCounts(Map<String, int> m) {
  var total = 0;
  for (final v in m.values) {
    total += v;
  }
  return total;
}

bool isTracked(ReelApp a, Map<String, int> settings) {
  return (settings['track:${a.key}'] ?? (a.defaultOn ? 1 : 0)) == 1;
}

/// Sum of one day's values over the apps that are being tracked.
int sumTracked(Map<String, int> day, Map<String, int> settings) {
  var total = 0;
  for (final a in reelApps) {
    if (isTracked(a, settings)) total += day[a.key] ?? 0;
  }
  return total;
}

String fmtDuration(int secs) {
  if (secs <= 0) return 'no time';
  if (secs < 60) return '<1 min';
  final m = (secs + 30) ~/ 60;
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}

String fmtHour(int h) => '${h.toString().padLeft(2, '0')}:00';

/// How healthy the sprout is right now: 1 = fresh, 0 = wilted.
/// Uses the tightest of your limits. With no limit, it slowly droops over 100 reels.
double plantHealth(Map<String, int> today, Map<String, int> s) {
  var health = 1.0;
  var anyLimit = false;
  final total = s['total'] ?? -1;
  if (total > 0) {
    anyLimit = true;
    health = 1 - sumTracked(today, s) / total;
  } else if (total == 0) {
    return 0;
  }
  for (final a in reelApps) {
    if (!isTracked(a, s)) continue;
    final l = s['limit:${a.key}'] ?? -1;
    if (l > 0) {
      anyLimit = true;
      final h = 1 - (today[a.key] ?? 0) / l;
      if (h < health) health = h;
    }
  }
  if (!anyLimit) health = 1 - sumTracked(today, s) / 100;
  return health.clamp(0.0, 1.0).toDouble();
}

/// The limit to draw as ticks: the daily total, or the one app limit if that's all there is.
({int count, int limit})? tickTarget(Map<String, int> today, Map<String, int> s) {
  final total = s['total'] ?? -1;
  if (total > 0) return (count: sumTracked(today, s), limit: total);
  final withLimits = [
    for (final a in reelApps)
      if (isTracked(a, s) && (s['limit:${a.key}'] ?? -1) > 0) a,
  ];
  if (withLimits.length == 1) {
    final a = withLimits.first;
    return (count: today[a.key] ?? 0, limit: s['limit:${a.key}']!);
  }
  return null;
}

/// "Shorts", "reels", or "Shorts and reels", depending on what you track.
String trackedNoun(Map<String, int> s) {
  final nouns = <String>[];
  for (final a in reelApps) {
    if (isTracked(a, s) && !nouns.contains(a.noun)) nouns.add(a.noun);
  }
  if (nouns.isEmpty) return 'reels';
  if (nouns.length == 1) return nouns.first;
  return '${nouns.sublist(0, nouns.length - 1).join(', ')} and ${nouns.last}';
}

/// Days in a row (counting today) that stayed within your limit.
/// Returns null if no limit is set, so the screen can ask you to set one.
int? streakDays(Map<String, Map<String, int>> hist, Map<String, int> s) {
  final totalLimit = s['total'] ?? -1;
  final perApp = <String, int>{};
  for (final a in reelApps) {
    if (!isTracked(a, s)) continue;
    final l = s['limit:${a.key}'] ?? -1;
    if (l > 0) perApp[a.key] = l;
  }
  if (totalLimit <= 0 && perApp.isEmpty) return null;
  if (hist.isEmpty) return 0;

  String first = hist.keys.first;
  for (final k in hist.keys) {
    if (k.compareTo(first) < 0) first = k;
  }

  final now = DateTime.now();
  var streak = 0;
  for (var i = 0; i < 400; i++) {
    final d = DateTime(now.year, now.month, now.day - i);
    final key = dateKey(d);
    if (key.compareTo(first) < 0) break;
    final day = hist[key] ?? <String, int>{};
    var ok = true;
    if (totalLimit > 0 && sumTracked(day, s) > totalLimit) ok = false;
    perApp.forEach((k, l) {
      if ((day[k] ?? 0) > l) ok = false;
    });
    if (!ok) break;
    streak++;
  }
  return streak;
}
