import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'engine.dart';
import 'model.dart';

enum Scr { home, pick, end, grid, ring }

class Draft {
  int start;
  int? end;
  int interval;
  bool custom;
  List<int> skipped;
  String label;
  List<int> days;
  String sound;
  bool vib;
  int? editingId;
  Draft({
    required this.start,
    this.end,
    required this.interval,
    this.custom = false,
    List<int>? skipped,
    this.label = '',
    List<int>? days,
    String? sound,
    this.vib = true,
    this.editingId,
  }) : skipped = skipped ?? [],
       days = days ?? [],
       sound = sound ?? sounds[0];

  bool get hasEnd => end != null;
  List<int> get slots => slotsFor(hasEnd, start, end, interval);
  bool isSkipped(int t) => skipped.contains(t % 1440);
  List<int> get active => slots.where((t) => !isSkipped(t)).toList();
}

class RingInfo {
  final Alarm alarm;
  final List<int> act;
  final int i;
  final int? next;
  final List<int> rest;
  final int slot;
  final bool preview;
  RingInfo(this.alarm, this.act, this.i, this.next, this.rest, this.slot, this.preview);
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  late final Engine engine;
  List<Alarm> alarms = [];
  String theme = 'crimson';
  bool use24h = false;
  int defaultInterval = 10;

  Scr screen = Scr.home;
  Draft? draft;
  int wheelGen = 0; // bump to force picker wheels to re-sync to draft
  ActiveRing? ring;
  String? toast;
  int? highlightId;
  bool scrubbing = false;
  int finderMin = 0;
  DateTime now = DateTime.now();
  Map<String, bool> health = {};
  bool loaded = false;
  void Function(int id)? scrollCardTo;

  Timer? _tick, _toastT, _flashT;
  String? _pendingToast;

  int get nowMin => now.hour * 60 + now.minute;

  Future<void> init() async {
    engine = Engine(_onEvent);
    WidgetsBinding.instance.addObserver(this);
    finderMin = nowMin;
    try {
      final s = await engine.getSettings();
      theme = s['theme'] as String? ?? 'crimson';
      use24h = s['use24h'] as bool? ?? false;
      defaultInterval = (s['defaultInterval'] as num?)?.toInt() ?? 10;
      final a = await engine.getAlarms();
      alarms = a ?? await engine.saveAlarms(seedAlarms());
      await refreshHealth();
      if (health['notifications'] == false) await engine.fix('notifications');
      await refreshRing();
    } catch (e) {
      debugPrint('engine init failed: $e');
    }
    loaded = true;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = DateTime.now();
      final changed = n.minute != now.minute;
      now = n;
      if (changed) notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      now = DateTime.now();
      reloadAlarms();
      refreshRing();
      refreshHealth();
    }
  }

  void _onEvent(String e) {
    switch (e) {
      case 'alarmsChanged':
        reloadAlarms();
      case 'ringChanged':
        refreshRing();
      case 'healthChanged':
        refreshHealth();
    }
  }

  Future<void> reloadAlarms() async {
    final a = await engine.getAlarms();
    if (a != null) {
      alarms = a;
      notifyListeners();
    }
  }

  Future<void> refreshHealth() async {
    health = await engine.health();
    notifyListeners();
  }

  List<String> get criticalIssues => ['notifications', 'fullScreen', 'exact'].where((k) => health[k] == false).toList();

  Future<void> refreshRing() async {
    final r = await engine.activeRing();
    if (r != null) {
      ring = r;
      if (screen != Scr.ring) {
        screen = Scr.ring;
        dragReset++;
      }
    } else if (screen == Scr.ring || ring != null) {
      ring = null;
      screen = Scr.home;
      draft = null;
      engine.ringDone();
      if (_pendingToast != null) showToast(_pendingToast!);
      _pendingToast = null;
    }
    notifyListeners();
  }

  int dragReset = 0;

  // ---------- settings ----------
  Future<void> setSettings({String? theme, bool? use24h, int? defaultInterval}) async {
    if (theme != null) this.theme = theme;
    if (use24h != null) this.use24h = use24h;
    if (defaultInterval != null) this.defaultInterval = defaultInterval;
    notifyListeners();
    await engine.saveSettings({'theme': this.theme, 'use24h': this.use24h, 'defaultInterval': this.defaultInterval});
  }

  // ---------- feedback ----------
  void showToast(String t) {
    toast = t;
    _toastT?.cancel();
    _toastT = Timer(const Duration(milliseconds: 2400), () {
      toast = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void flash(int id) {
    highlightId = id;
    _flashT?.cancel();
    _flashT = Timer(const Duration(milliseconds: 1800), () {
      highlightId = null;
      scrubbing = false;
      notifyListeners();
    });
    notifyListeners();
  }

  void go(Scr s) {
    screen = s;
    notifyListeners();
  }

  // ---------- persistence ----------
  Future<void> _persist() async {
    notifyListeners();
    try {
      alarms = await engine.saveAlarms(alarms);
    } catch (e) {
      showToast('COULD NOT SAVE');
    }
    notifyListeners();
  }

  void toggle(Alarm a) {
    a.on = !a.on;
    if (a.on) {
      a.armedAt = DateTime.now().millisecondsSinceEpoch;
      a.skipBefore = 0;
      final n = a.nextAfter(DateTime.now());
      if (n != null) showToast('RINGS IN ${dur(_minsUntil(n))}');
    }
    _persist();
  }

  int _minsUntil(DateTime t) {
    final s = t.difference(DateTime.now()).inSeconds;
    return ((s + 59) ~/ 60).clamp(1, 1 << 30);
  }

  // ---------- editing ----------
  void newAlarm() {
    draft = Draft(start: 7 * 60, interval: defaultInterval);
    wheelGen++;
    go(Scr.pick);
  }

  void edit(Alarm a) {
    draft = Draft(
      start: a.start,
      end: a.isRange ? a.end : null,
      interval: a.interval,
      custom: !presets.contains(a.interval),
      skipped: [...a.skipped],
      label: a.label,
      days: [...a.days],
      sound: a.sound,
      vib: a.vib,
      editingId: a.id,
    );
    wheelGen++;
    go(a.isRange ? Scr.grid : Scr.pick);
  }

  int get pickMin => screen == Scr.end ? (draft?.end ?? 0) : (draft?.start ?? 0);
  void setPick(int m) {
    final d = draft;
    if (d == null) return;
    if (screen == Scr.end) {
      d.end = m;
    } else {
      d.start = m;
    }
    notifyListeners();
  }

  void upd(void Function(Draft d) f) {
    if (draft == null) return;
    f(draft!);
    notifyListeners();
  }

  void pickBack() {
    if (screen == Scr.end) {
      wheelGen++;
      go(Scr.pick);
    } else {
      draft = null;
      go(Scr.home);
    }
  }

  void pickConfirm() => screen == Scr.end ? go(Scr.grid) : save();

  void goEnd() {
    final d = draft!;
    d.end ??= (d.start + 120) % 1440;
    wheelGen++;
    go(Scr.end);
  }

  void clearEnd() => upd((d) {
    d.end = null;
    d.skipped = [];
  });

  void addDur(int x) {
    upd((d) => d.end = (d.start + x) % 1440);
    wheelGen++;
    notifyListeners();
  }

  void gridBack() {
    wheelGen++;
    go(Scr.end);
  }

  void cycleSound() {
    upd((d) => d.sound = sounds[(sounds.indexOf(d.sound) + 1) % sounds.length]);
    engine.previewSound(draft!.sound);
  }

  void toggleVib() {
    upd((d) => d.vib = !d.vib);
    if (draft!.vib) HapticFeedback.heavyImpact();
  }

  void cycleRepeat() => upd((d) {
    final j = ([...d.days]..sort()).join(',');
    final i = repeats.indexWhere((r) => r.join(',') == j);
    d.days = [...repeats[(i + 1) % repeats.length]];
  });

  void toggleSlot(int t) => upd((d) {
    final k = t % 1440;
    d.skipped.contains(k) ? d.skipped.remove(k) : d.skipped.add(k);
  });

  void save() {
    final d = draft!;
    final isR = d.end != null;
    final a = Alarm(
      id: d.editingId ?? DateTime.now().millisecondsSinceEpoch,
      type: isR ? 'range' : 'single',
      start: d.start,
      end: isR ? d.end : null,
      interval: d.interval,
      skipped: isR ? [...d.skipped] : [],
      label: d.label.trim(),
      days: [...d.days],
      sound: d.sound,
      vib: d.vib,
      on: true,
      armedAt: DateTime.now().millisecondsSinceEpoch,
    );
    if (d.editingId != null) {
      alarms = [for (final x in alarms) x.id == d.editingId ? a : x];
    } else {
      alarms = [...alarms, a];
    }
    final n = a.nextAfter(DateTime.now());
    final msg = isR
        ? '${a.activeSlots.length} ALARMS SET'
        : (n != null
              ? 'ALARM SET ${fs(a.start, use24h)} · IN ${dur(_minsUntil(n))}'
              : 'ALARM SET ${fs(a.start, use24h)}');
    draft = null;
    screen = Scr.home;
    _persist();
    showToast(msg);
    flash(a.id);
    Future.delayed(const Duration(milliseconds: 120), () => scrollCardTo?.call(a.id));
  }

  void deleteAlarm(int id) {
    HapticFeedback.heavyImpact();
    alarms = alarms.where((x) => x.id != id).toList();
    _persist();
    showToast('ALARM DELETED');
  }

  /// Set by the finder; lets the card carousel drive it.
  void Function(double minute)? scrollFinderTo;

  /// Cards were scrolled by the user to [m] (fractional minute between card starts).
  void onCardsScrolled(double m, Alarm? focused) {
    scrollFinderTo?.call(m);
    finderMin = m.round().clamp(0, 1439);
    scrubbing = true;
    if (focused != null && focused.id != highlightId) {
      HapticFeedback.selectionClick();
      flash(focused.id);
    } else if (focused != null) {
      flash(focused.id);
    }
    notifyListeners();
  }

  void delete() {
    HapticFeedback.heavyImpact();
    final id = draft!.editingId;
    alarms = alarms.where((x) => x.id != id).toList();
    draft = null;
    screen = Scr.home;
    _persist();
    showToast('ALARM DELETED');
  }

  // ---------- home ----------
  List<Alarm> get sorted => [...alarms]..sort((a, b) => a.start.compareTo(b.start));

  ({Alarm a, int t, int d})? nearest(int m) {
    ({Alarm a, int t, int d})? best;
    for (final a in alarms) {
      for (final t in a.slots) {
        final d = cdist(t % 1440, m);
        if (best == null || d < best.d) best = (a: a, t: t, d: d);
      }
    }
    return best;
  }

  ({Alarm a, DateTime at})? nextUp() {
    ({Alarm a, DateTime at})? best;
    final n = DateTime.now();
    for (final a in alarms) {
      if (!a.on) continue;
      final x = a.nextAfter(n);
      if (x != null && (best == null || x.isBefore(best.at))) best = (a: a, at: x);
    }
    return best;
  }

  int minsUntil(DateTime t) => _minsUntil(t);

  int _lastFinderHour = -1;
  void onFinder(int m) {
    final n = nearest(m);
    final changed = n != null && n.a.id != highlightId;
    finderMin = m;
    scrubbing = true;
    if (n != null) {
      flash(n.a.id);
      if (changed) {
        HapticFeedback.selectionClick();
        scrollCardTo?.call(n.a.id);
      }
    }
    if (m ~/ 60 != _lastFinderHour) {
      _lastFinderHour = m ~/ 60;
      HapticFeedback.selectionClick();
    }
    notifyListeners();
  }

  void openRing() {
    final n = nextUp();
    if (n == null) {
      HapticFeedback.heavyImpact();
      showToast('NO ACTIVE ALARMS');
      return;
    }
    engine.preview(n.a.id);
  }

  // ---------- ringing ----------
  RingInfo? get ringInfo {
    final r = ring;
    if (r == null) return null;
    Alarm? a;
    for (final x in alarms) {
      if (x.id == r.alarmId) a = x;
    }
    if (a == null) return null;
    final act = a.activeSlots;
    var i = act.indexOf(r.slot);
    if (i < 0) i = 0;
    return RingInfo(
      a,
      act,
      i,
      i + 1 < act.length ? act[i + 1] : null,
      act.length > i + 1 ? act.sublist(i + 1) : [],
      r.slot,
      r.preview,
    );
  }

  void _endRing(String action, String msg) {
    _pendingToast = msg;
    engine.ringAction(action);
  }

  void snooze() => _endRing('snooze', ringInfo?.preview == true ? 'PREVIEW ENDED' : 'SNOOZED 9 MIN');
  void stop() => _endRing('stop', 'ALARM STOPPED');
  void skipRest() {
    final ri = ringInfo;
    _endRing('skipRest', ri?.preview == true ? 'PREVIEW ENDED' : 'SKIPPED ${ri?.rest.length ?? 0} REMAINING');
  }
}
