import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_alarms/model.dart';
import 'package:interval_alarms/screens/grid.dart';
import 'package:interval_alarms/screens/home.dart';
import 'package:interval_alarms/screens/pick.dart';
import 'package:interval_alarms/state.dart';
import 'package:interval_alarms/theme.dart';

AppState _state() {
  final s = AppState();
  final now = DateTime.now().millisecondsSinceEpoch;
  s.alarms = [
    Alarm(id: 1, type: 'single', start: 390, label: 'Wake up', on: true, days: [0, 1, 2, 3, 4], sound: 'KIND OF BLUE', armedAt: now),
    Alarm(id: 2, type: 'range', start: 600, end: 720, interval: 10, skipped: [630], label: 'Hydrate', on: true, days: [0, 1, 2, 3, 4, 5, 6], sound: 'BEEP BEEP', armedAt: now),
    Alarm(id: 3, type: 'single', start: 1320, label: 'Lunch call', on: false, sound: 'RADAR'),
  ];
  s.loaded = true;
  return s;
}

Widget _wrap(AppState s, Widget child) => PalScope(
  pal: palettes['crimson']!,
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  for (final size in const [Size(411, 891), Size(360, 740), Size(390, 844)]) {
    testWidgets('screens lay out without overflow at $size', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final s = _state();

      await tester.pumpWidget(_wrap(s, HomeScreen(s)));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      s.draft = Draft(start: 600, end: 720, interval: 10);
      s.screen = Scr.pick;
      await tester.pumpWidget(_wrap(s, PickScreen(s, key: const ValueKey('p'))));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      s.screen = Scr.end;
      await tester.pumpWidget(_wrap(s, PickScreen(s, key: const ValueKey('e'))));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      s.screen = Scr.grid;
      await tester.pumpWidget(_wrap(s, GridScreen(s)));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
