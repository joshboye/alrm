import 'package:flutter_test/flutter_test.dart';
import 'package:interval_alarms/model.dart';

void main() {
  final mon9 = DateTime(2026, 11, 9, 9, 41); // Monday 09:41

  test('range slots include both ends', () {
    expect(slotsFor(true, 600, 720, 10).length, 13);
    expect(slotsFor(true, 1380, 60, 30), [1380, 1410, 1440, 1470, 1500]); // overnight
  });

  test('repeating range skips permanently skipped slots', () {
    final a = Alarm(id: 1, type: 'range', start: 600, end: 720, interval: 10, skipped: [600, 610], days: [0, 1, 2, 3, 4, 5, 6]);
    expect(a.nextAfter(mon9), DateTime(2026, 11, 9, 10, 20));
  });

  test('inside a range, the next slot today is picked', () {
    final a = Alarm(id: 1, type: 'range', start: 540, end: 660, interval: 15, days: [0]);
    expect(a.nextAfter(mon9), DateTime(2026, 11, 9, 9, 45));
  });

  test('weekday filter', () {
    final a = Alarm(id: 1, type: 'single', start: 390, days: [5, 6]); // weekends 06:30
    expect(a.nextAfter(mon9), DateTime(2026, 11, 14, 6, 30));
  });

  test('one-time single rings once, then has nothing', () {
    final armed = DateTime(2026, 11, 9, 9, 0).millisecondsSinceEpoch;
    final a = Alarm(id: 1, type: 'single', start: 600, days: [], armedAt: armed);
    final first = a.nextAfter(mon9)!;
    expect(first, DateTime(2026, 11, 9, 10, 0));
    expect(a.nextAfter(first), isNull);
  });

  test('one-time single set after its time goes to tomorrow', () {
    final a = Alarm(id: 1, type: 'single', start: 420, days: [], armedAt: mon9.millisecondsSinceEpoch);
    expect(a.nextAfter(mon9), DateTime(2026, 11, 10, 7, 0));
  });

  test('skip remaining affects only this occurrence', () {
    final a = Alarm(id: 1, type: 'range', start: 540, end: 660, interval: 15, days: [0, 1],
        skipBefore: DateTime(2026, 11, 9, 11, 0).millisecondsSinceEpoch);
    expect(a.nextAfter(mon9), DateTime(2026, 11, 10, 9, 0));
  });

  test('overnight range continues after midnight', () {
    final a = Alarm(id: 1, type: 'range', start: 1380, end: 60, interval: 30, days: [0]);
    expect(a.nextAfter(DateTime(2026, 11, 10, 0, 10)), DateTime(2026, 11, 10, 0, 30));
  });
}
