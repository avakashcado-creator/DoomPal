import 'package:flutter/services.dart';

/// Thin wrapper around the Kotlin side (MainActivity.kt).
class Native {
  static const MethodChannel _ch = MethodChannel('doompal/native');

  static Future<bool> isServiceEnabled() async {
    final v = await _ch.invokeMethod<bool>('isServiceEnabled');
    return v ?? false;
  }

  static Future<void> openAccessibilitySettings() async {
    await _ch.invokeMethod<void>('openAccessibilitySettings');
  }

  static Future<bool> batteryUnrestricted() async {
    final v = await _ch.invokeMethod<bool>('isBatteryUnrestricted');
    return v ?? false;
  }

  static Future<void> openBatterySettings() async {
    await _ch.invokeMethod<void>('openBatterySettings');
  }

  static Future<void> openAppInfo() async {
    await _ch.invokeMethod<void>('openAppInfo');
  }

  /// date (yyyy-MM-dd) -> app key -> count
  static Future<Map<String, Map<String, int>>> history() async {
    final raw = await _ch.invokeMethod<Map<dynamic, dynamic>>('getHistory');
    final out = <String, Map<String, int>>{};
    if (raw == null) return out;
    raw.forEach((date, apps) {
      final m = <String, int>{};
      (apps as Map<dynamic, dynamic>).forEach((k, v) {
        m[k as String] = (v as num).toInt();
      });
      out[date as String] = m;
    });
    return out;
  }

  /// date -> app key -> estimated seconds spent
  static Future<Map<String, Map<String, int>>> timeHistory() async {
    final raw = await _ch.invokeMethod<Map<dynamic, dynamic>>('getTime');
    final out = <String, Map<String, int>>{};
    if (raw == null) return out;
    raw.forEach((date, apps) {
      final m = <String, int>{};
      (apps as Map<dynamic, dynamic>).forEach((k, v) {
        m[k as String] = (v as num).toInt();
      });
      out[date as String] = m;
    });
    return out;
  }

  static Future<Map<String, int>> settings() async {
    final raw = await _ch.invokeMethod<Map<dynamic, dynamic>>('getSettings');
    final out = <String, int>{};
    if (raw == null) return out;
    raw.forEach((k, v) {
      out[k as String] = (v as num).toInt();
    });
    return out;
  }

  /// lastApp (key or ''), lastTime (ms since epoch), snoozeUntil (ms since epoch)
  static Future<NativeStatus> status() async {
    final raw = await _ch.invokeMethod<Map<dynamic, dynamic>>('getStatus');
    if (raw == null) return const NativeStatus('', 0, 0, 0, 0);
    return NativeStatus(
      (raw['lastApp'] as String?) ?? '',
      ((raw['lastTime'] as num?) ?? 0).toInt(),
      ((raw['snoozeUntil'] as num?) ?? 0).toInt(),
      ((raw['snoozesToday'] as num?) ?? 0).toInt(),
      ((raw['bonusToday'] as num?) ?? 0).toInt(),
      ((raw['guestUntil'] as num?) ?? 0).toInt(),
      ((raw['guestUsesToday'] as num?) ?? 0).toInt(),
    );
  }

  /// Asks to change a setting. Stricter changes apply at once. Looser ones wait out the lock.
  static Future<SetResult> setSetting(String key, int value) async {
    final raw = await _ch.invokeMethod<Map<dynamic, dynamic>>('setSetting', {'key': key, 'value': value});
    return SetResult(
      (raw?['status'] as String?) ?? 'applied',
      ((raw?['applyAt'] as num?) ?? 0).toInt(),
      ((raw?['hours'] as num?) ?? 0).toInt(),
    );
  }

  static Future<List<PendingChange>> pending() async {
    final raw = await _ch.invokeMethod<List<dynamic>>('getPending');
    return (raw ?? const <dynamic>[]).map((e) {
      final m = e as Map<dynamic, dynamic>;
      return PendingChange(m['key'] as String, (m['value'] as num).toInt(), (m['at'] as num).toInt());
    }).toList();
  }

  static Future<void> cancelPending(String key) async {
    await _ch.invokeMethod<void>('cancelPending', {'key': key});
  }

  static Future<CoachInfo> coach() async {
    final raw = await _ch.invokeMethod<Map<dynamic, dynamic>>('getCoach');
    final m = raw ?? <dynamic, dynamic>{};
    final note = (m['note'] as String?) ?? 'hold|';
    final cut = note.indexOf('|');
    return CoachInfo(
      pct: ((m['pct'] as num?) ?? 0).toInt(),
      adExtra: ((m['ad'] as num?) ?? 0).toInt(),
      begCut: ((m['beg'] as num?) ?? 0).toInt(),
      risk: ((m['risk'] as List<dynamic>?) ?? const <dynamic>[]).map((e) => (e as num).toInt()).toList(),
      mood: cut < 0 ? 'hold' : note.substring(0, cut),
      note: cut < 0 ? note : note.substring(cut + 1),
      swipes: ((m['swipes'] as num?) ?? 0).toInt(),
      pauseSecs: ((m['pause'] as num?) ?? 0).toDouble(),
      trained: (m['trained'] as bool?) ?? false,
      minTrain: ((m['minTrain'] as num?) ?? 100).toInt(),
    );
  }

  static Future<String> chat() async {
    final v = await _ch.invokeMethod<String>('getChat');
    return v ?? '';
  }

  static Future<void> addChat(String who, String text) async {
    await _ch.invokeMethod<void>('addChat', {'who': who, 'text': text});
  }

  /// Absolute paths of the pictures you added (private copies inside DoomPal).
  static Future<List<String>> listPictures() async {
    final raw = await _ch.invokeMethod<List<dynamic>>('listPictures');
    return (raw ?? const <dynamic>[]).map((e) => e as String).toList();
  }

  /// Opens the gallery picker, or the file picker if [files] is true.
  /// Returns how many pictures were added.
  static Future<int> pickPictures({bool files = false}) async {
    final n = await _ch.invokeMethod<int>('pickPictures', {'source': files ? 'files' : 'gallery'});
    return n ?? 0;
  }

  static Future<void> removePicture(String path) async {
    await _ch.invokeMethod<void>('removePicture', {'path': path});
  }

  static Future<void> clearPictures() async {
    await _ch.invokeMethod<void>('clearPictures');
  }

  static Future<String> log() async {
    final v = await _ch.invokeMethod<String>('getLog');
    return v ?? '';
  }

  static Future<void> clearLog() async {
    await _ch.invokeMethod<void>('clearLog');
  }

  static Future<void> clearHistory() async {
    await _ch.invokeMethod<void>('clearHistory');
  }
}

class NativeStatus {
  final String lastApp;
  final int lastTime;
  final int snoozeUntil;
  final int snoozesToday;
  final int bonusToday;
  final int guestUntil;
  final int guestUsesToday;
  const NativeStatus(this.lastApp, this.lastTime, this.snoozeUntil, this.snoozesToday, this.bonusToday,
      [this.guestUntil = 0, this.guestUsesToday = 0]);
}

class SetResult {
  final String status; // applied or queued
  final int applyAt;
  final int hours;
  const SetResult(this.status, this.applyAt, this.hours);
  bool get queued => status == 'queued';
}

class PendingChange {
  final String key;
  final int value;
  final int at;
  const PendingChange(this.key, this.value, this.at);
}

class CoachInfo {
  final int pct;
  final int adExtra;
  final int begCut;
  final List<int> risk;
  final String mood; // tight, relax, hold or off
  final String note;
  final int swipes;
  final double pauseSecs;
  final bool trained;
  final int minTrain;
  const CoachInfo({
    required this.pct,
    required this.adExtra,
    required this.begCut,
    required this.risk,
    required this.mood,
    required this.note,
    required this.swipes,
    required this.pauseSecs,
    required this.trained,
    required this.minTrain,
  });
}
