// Alarm model + time helpers. Mirrors android/.../Scheduler.kt — keep the two in sync.

const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const sounds = ['WAKE UP', 'KIND OF BLUE', 'BEEP BEEP', 'RADAR', 'MORNING'];
const repeats = <List<int>>[
  [],
  [0, 1, 2, 3, 4],
  [0, 1, 2, 3, 4, 5, 6],
  [5, 6],
];
const presets = [5, 10, 15, 20, 30];

String pad(int n) => n.toString().padLeft(2, '0');

class Fmt {
  final String t, ap;
  const Fmt(this.t, this.ap);
}

Fmt fmt(int m, bool h24) {
  m = ((m % 1440) + 1440) % 1440;
  final h = m ~/ 60, mm = pad(m % 60);
  if (h24) return Fmt('${pad(h)}:$mm', '');
  final hh = h % 12 == 0 ? 12 : h % 12;
  return Fmt('${pad(hh)}:$mm', h < 12 ? 'AM' : 'PM');
}

String fs(int m, bool h24) {
  final f = fmt(m, h24);
  return f.ap.isNotEmpty ? '${f.t} ${f.ap}' : f.t;
}

String daysText(List<int> d) {
  if (d.isEmpty) return 'NO';
  if (d.length == 7) return 'DAILY';
  final s = [...d]..sort();
  final j = s.join(',');
  if (j == '0,1,2,3,4') return 'WEEKDAYS';
  if (j == '5,6') return 'WEEKENDS';
  return s.map((i) => dayNames[i]).join(' ');
}

String dur(int m) {
  final h = m ~/ 60, mm = m % 60;
  if (h > 0) return mm > 0 ? '${h}H ${mm}M' : '${h}H';
  return '$mm MIN';
}

int cdist(int a, int b) {
  final d = (a - b).abs() % 1440;
  return d < 1440 - d ? d : 1440 - d;
}

int endU(int start, int end) => end <= start ? end + 1440 : end;

List<int> slotsFor(bool isRange, int start, int? end, int interval) {
  if (!isRange || end == null) return [start];
  final e = endU(start, end), iv = interval < 1 ? 1 : interval;
  return [for (var t = start; t <= e; t += iv) t];
}

class Alarm {
  int id;
  String type; // single | range
  int start;
  int? end;
  int interval;
  List<int> skipped;
  String label;
  bool on;
  List<int> days;
  String sound;
  bool vib;
  int armedAt;
  int skipBefore;

  Alarm({
    required this.id,
    required this.type,
    required this.start,
    this.end,
    this.interval = 10,
    List<int>? skipped,
    this.label = '',
    this.on = true,
    List<int>? days,
    this.sound = 'WAKE UP',
    this.vib = true,
    this.armedAt = 0,
    this.skipBefore = 0,
  }) : skipped = skipped ?? [],
       days = days ?? [];

  bool get isRange => type == 'range' && end != null;
  List<int> get slots => slotsFor(isRange, start, end, interval);
  bool isSkipped(int t) => skipped.contains(t % 1440);
  List<int> get activeSlots => slots.where((t) => !isSkipped(t)).toList();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'start': start,
    'end': end,
    'interval': interval,
    'skipped': skipped,
    'label': label,
    'on': on,
    'days': days,
    'sound': sound,
    'vib': vib,
    'armedAt': armedAt,
    'skipBefore': skipBefore,
  };

  factory Alarm.fromJson(Map<String, dynamic> j) => Alarm(
    id: (j['id'] as num).toInt(),
    type: j['type'] as String? ?? 'single',
    start: (j['start'] as num?)?.toInt() ?? 0,
    end: (j['end'] as num?)?.toInt(),
    interval: (j['interval'] as num?)?.toInt() ?? 10,
    skipped: [for (final x in (j['skipped'] as List? ?? [])) (x as num).toInt()],
    label: j['label'] as String? ?? '',
    on: j['on'] as bool? ?? false,
    days: [for (final x in (j['days'] as List? ?? [])) (x as num).toInt()],
    sound: j['sound'] as String? ?? sounds[0],
    vib: j['vib'] as bool? ?? true,
    armedAt: (j['armedAt'] as num?)?.toInt() ?? 0,
    skipBefore: (j['skipBefore'] as num?)?.toInt() ?? 0,
  );

  /// Next ring strictly after [after] — same rules as Scheduler.nextFor (Kotlin).
  DateTime? nextAfter(DateTime after) {
    final sl = slots;
    final oneTime = days.isEmpty;
    final a = after.millisecondsSinceEpoch;
    DateTime at(DateTime d, int t) => DateTime(d.year, d.month, d.day, 0, t);
    final today = DateTime(after.year, after.month, after.day);
    DateTime? best;
    for (var off = -1; off <= 8; off++) {
      final d = DateTime(today.year, today.month, today.day + off);
      if (!oneTime && !days.contains(d.weekday - 1)) continue;
      if (oneTime && at(d, sl.last).millisecondsSinceEpoch <= armedAt) continue;
      for (final t in sl) {
        if (isSkipped(t)) continue;
        final x = at(d, t), xm = x.millisecondsSinceEpoch;
        if (xm <= a || xm <= skipBefore || (oneTime && xm <= armedAt)) continue;
        if (best == null || x.isBefore(best)) best = x;
        break;
      }
      if (oneTime) break;
    }
    return best;
  }
}

List<Alarm> seedAlarms() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    Alarm(
      id: 1,
      type: 'single',
      start: 6 * 60 + 30,
      label: 'Wake up',
      on: false,
      days: [0, 1, 2, 3, 4],
      sound: 'KIND OF BLUE',
      armedAt: now,
    ),
    Alarm(
      id: 2,
      type: 'range',
      start: 10 * 60,
      end: 12 * 60,
      interval: 10,
      skipped: [10 * 60 + 30, 11 * 60 + 20],
      label: 'Hydrate',
      on: false,
      days: [0, 1, 2, 3, 4, 5, 6],
      sound: 'BEEP BEEP',
      armedAt: now,
    ),
  ];
}
