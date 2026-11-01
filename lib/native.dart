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
    if (raw == null) return const NativeStatus('', 0, 0, 0);
    return NativeStatus(
      (raw['lastApp'] as String?) ?? '',
      ((raw['lastTime'] as num?) ?? 0).toInt(),
      ((raw['snoozeUntil'] as num?) ?? 0).toInt(),
      ((raw['snoozesToday'] as num?) ?? 0).toInt(),
    );
  }

  static Future<void> setSetting(String key, int value) async {
    await _ch.invokeMethod<void>('setSetting', {'key': key, 'value': value});
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
  const NativeStatus(
      this.lastApp, this.lastTime, this.snoozeUntil, this.snoozesToday);
}
