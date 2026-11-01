import 'dart:math' as math;

/// What Doomy says inside the app, in Gen Alpha. The overlays have their own lines in DoomyLines.kt.
/// He roasts the habit, never the person.
class DoomyMood {
  final String expr;
  final String text;
  final String top;
  final String bottom;
  const DoomyMood(this.expr, this.text, this.top, this.bottom);
}

final _rnd = math.Random();
T pick<T>(List<T> list) => list[_rnd.nextInt(list.length)];

const punchlines = [
  'BRAIN.EXE HAS STOPPED',
  'ONE MORE (LIE)',
  "IT'S 2AM AND I KNOW 40 DANCES",
  'AURA: -9000',
  'I AM SO COOKED',
  'THUMB TIRED. ME NOT YET',
  'NPC BEHAVIOR',
];

String _minsGone(int secs) {
  final m = secs ~/ 60;
  if (m < 1) return 'BARELY STARTED';
  if (m < 60) return '$m MIN GONE';
  return '${m ~/ 60} HOURS GONE';
}

DoomyMood moodFor({
  required bool counting,
  required int total,
  required int secs,
  required String noun,
  required ({int count, int limit})? ticks,
}) {
  final upperNoun = noun.toUpperCase();
  if (!counting) {
    return const DoomyMood(
      'judge',
      "bro i can't see anything rn. turn me on in Accessibility so i can judge u properly.",
      'DOOMY IS',
      'BLINDFOLDED',
    );
  }
  if (total == 0) {
    return DoomyMood(
      'smug',
      '0 today?? who are u. big aura. weirded out, but proud.',
      '0 $upperNoun TODAY',
      'AURA +500',
    );
  }
  final t = ticks;
  if (t != null && t.limit > 0) {
    final used = t.count / t.limit;
    final left = t.limit - t.count;
    final top = '${t.count} $upperNoun TODAY';
    if (used >= 1) {
      return DoomyMood(
          'dead', "${t.count}. ur cooked. we're done for today, pack it up.", top, 'DOOMY SAYS NO');
    }
    if (used >= 0.8) {
      return DoomyMood(
          'shocked', "only $left left?? lock in bro. i'm stretching my 'no' muscles.", top, 'SEND HELP');
    }
    if (used >= 0.5) {
      return DoomyMood('judge', "${t.count} $noun. $left left. choose wisely, no cap.", top, _minsGone(secs));
    }
    return DoomyMood('chill', "${t.count} so far. i'm watching. 👀", top, _minsGone(secs));
  }
  final top = '$total $upperNoun TODAY';
  if (total < 20) {
    return DoomyMood('chill', '$total so far and no limit?? bold. set one in Rules.', top, _minsGone(secs));
  }
  return DoomyMood('shocked', "$total and no limit?? that's so ohio. go to Rules.", top, 'NO LIMITS (BAD)');
}

/// "about 3 boiled eggs" style comparisons, so the minutes feel real.
List<String> equivalents(int secs) {
  final m = secs / 60;
  final out = <String>[];
  if (m >= 10) out.add('🥚 ${(m / 10).floor()} ${m >= 20 ? 'eggs' : 'egg'} boiled');
  if (m >= 3.5) out.add('🎵 ${(m / 3.5).floor()} ${m >= 7 ? 'songs' : 'song'}');
  if (m >= 2) out.add('📖 ${(m / 2).floor()} book ${m >= 4 ? 'pages' : 'page'}');
  if (m >= 30) out.add('🚶 ${(m / 12).floor()} km walked');
  return out.take(3).toList();
}

const chatIntro = [
  "yo. i'm doomy.",
  'i count ur reels and i judge. lovingly. no cap.',
  "tap something below and let's talk.",
];

const quickReplies = ['how cooked am i?', 'roast me', 'send a meme', "i'll stop now"];

List<String> roast(int total, String noun, int mins) => [
      pick([
        "$total $noun today. ur attention span called. it said 'who'",
        "i've seen goldfish with more focus. respectfully.",
        "u scroll like it's ur job. it doesn't pay bro.",
        'ur thumb did more cardio than u today',
        'ur screen time is giving NPC energy',
        if (mins >= 5) "$mins min of $noun. u could've learned a whole dance. wait. u probably did.",
      ]),
    ];

List<String> howBad(int total, String noun, String time, int week, ({int count, int limit})? t) {
  final verdict = t == null
      ? "no limit set tho. that's so ohio."
      : (t.count >= t.limit
          ? "over the limit. i'm not mad, just disappointed."
          : '${t.limit - t.count} left today. lock in.');
  return [
    'today: $total $noun, about $time.',
    'last 7 days: $week.',
    verdict,
  ];
}

const stopReplies = [
  ['say less. W. 🫡'],
  ['proud of u fr fr', 'go do something cool'],
  ['finally.', 'touch grass, report back'],
];
