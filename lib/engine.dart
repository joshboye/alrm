import 'dart:convert';
import 'package:flutter/services.dart';
import 'model.dart';

/// Ring currently active in the native AlarmService.
class ActiveRing {
  final int alarmId, slot, day, at;
  final bool preview, snooze;
  ActiveRing(this.alarmId, this.slot, this.day, this.at, this.preview, this.snooze);
  factory ActiveRing.fromJson(Map<String, dynamic> j) => ActiveRing(
    (j['alarmId'] as num).toInt(),
    (j['slot'] as num).toInt(),
    (j['day'] as num).toInt(),
    (j['at'] as num).toInt(),
    j['preview'] == true,
    j['snooze'] == true,
  );
}

/// Thin wrapper over the native alarm engine (MethodChannel "alrm/engine").
class Engine {
  static const _ch = MethodChannel('alrm/engine');
  final void Function(String event) onEvent;

  Engine(this.onEvent) {
    _ch.setMethodCallHandler((call) async => onEvent(call.method));
  }

  Future<List<Alarm>?> getAlarms() async {
    final s = await _ch.invokeMethod<String>('getAlarms');
    if (s == null) return null;
    return [for (final j in jsonDecode(s) as List) Alarm.fromJson(j as Map<String, dynamic>)];
  }

  Future<List<Alarm>> saveAlarms(List<Alarm> a) async {
    final s = await _ch.invokeMethod<String>('saveAlarms', jsonEncode([for (final x in a) x.toJson()]));
    return [for (final j in jsonDecode(s!) as List) Alarm.fromJson(j as Map<String, dynamic>)];
  }

  Future<Map<String, dynamic>> getSettings() async =>
      jsonDecode(await _ch.invokeMethod<String>('getSettings') ?? '{}') as Map<String, dynamic>;
  Future<void> saveSettings(Map<String, dynamic> s) => _ch.invokeMethod('saveSettings', jsonEncode(s));

  Future<ActiveRing?> activeRing() async {
    final s = jsonDecode(await _ch.invokeMethod<String>('getState') ?? '{}') as Map<String, dynamic>;
    final r = s['ring'];
    return r is Map<String, dynamic> ? ActiveRing.fromJson(r) : null;
  }

  Future<void> ringAction(String a) => _ch.invokeMethod('ringAction', a);
  Future<void> ringDone() => _ch.invokeMethod('ringDone');
  Future<void> preview(int alarmId) => _ch.invokeMethod('preview', alarmId);
  Future<void> previewSound(String name) => _ch.invokeMethod('previewSound', name);
  Future<Map<String, bool>> health() async {
    final m = jsonDecode(await _ch.invokeMethod<String>('health') ?? '{}') as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, v == true));
  }

  Future<void> fix(String key) => _ch.invokeMethod('fix', key);
}
