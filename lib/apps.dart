import 'package:flutter/material.dart';

/// Keys must match android_overlay/kotlin/Targets.kt
class ReelApp {
  final String key;
  final String label;
  final Color color;
  const ReelApp(this.key, this.label, this.color);
}

const List<ReelApp> reelApps = [
  ReelApp('instagram', 'Instagram Reels', Color(0xFFE1306C)),
  ReelApp('youtube', 'YouTube Shorts', Color(0xFFFF5252)),
  ReelApp('facebook', 'Facebook Reels', Color(0xFF4C8DF6)),
  ReelApp('snapchat', 'Snapchat Spotlight', Color(0xFFFFC400)),
];

const List<String> weekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun'
];

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
