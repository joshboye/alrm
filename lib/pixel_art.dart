import 'package:flutter/widgets.dart';
import 'model.dart';

/// 11×11 LCD-style pixel illustrations. '#' = lit segment.
const _art = <String, List<String>>{
  'sunrise': [
    '.....#.....',
    '.#...#...#.',
    '..#.....#..',
    '....###....',
    '...+++++...',
    '#.#######.#',
    '..#######..',
    '+++++++++++',
    '...........',
    '.+++++++++.',
    '...+++++...',
  ],
  'coffee': [
    '...+..+....',
    '..+..+.....',
    '...+..+....',
    '...........',
    '#########..',
    '#########.#',
    '#########.#',
    '##########.',
    '.#######...',
    '..#####....',
    '+++++++++++',
  ],
  'sun': [
    '.....#.....',
    '.#...#...#.',
    '..#.....#..',
    '....###....',
    '...#####...',
    '##.#####.##',
    '...#####...',
    '....###....',
    '..#.....#..',
    '.#...#...#.',
    '.....#.....',
  ],
  'sunset': [
    '...........',
    '...........',
    '....###....',
    '..#######..',
    '.#########.',
    '###########',
    '...........',
    '.+++++++++.',
    '...........',
    '...+++++...',
    '...........',
  ],
  'moon': [
    '....####...',
    '..####.....',
    '.####...#..',
    '.###...###.',
    '####....#..',
    '####.......',
    '####.....#.',
    '.####......',
    '.#######...',
    '..#######..',
    '....####...',
  ],
  'drop': [
    '.....#.....',
    '....###....',
    '....###....',
    '...#####...',
    '..#######..',
    '.#########.',
    '.#########.',
    '.##.######.',
    '.###.#####.',
    '..#######..',
    '...#####...',
  ],
  'dumbbell': [
    '...........',
    '...........',
    '.##.....##.',
    '.##.....##.',
    '###.....###',
    '###+++++###',
    '###.....###',
    '.##.....##.',
    '.##.....##.',
    '...........',
    '...........',
  ],
  'pill': [
    '...........',
    '...........',
    '..####+++..',
    '.#####...+.',
    '######....+',
    '######....+',
    '######....+',
    '.#####...+.',
    '..####+++..',
    '...........',
    '...........',
  ],
  'book': [
    '...........',
    '.++++.++++.',
    '+....+....+',
    '+.##.+.##.+',
    '+....+....+',
    '+.##.+.##.+',
    '+....+....+',
    '+.##.+.##.+',
    '+....+....+',
    '.++++.++++.',
    '.....+.....',
  ],
  'zzz': [
    '.....######',
    '.........#.',
    '........#..',
    '.......#...',
    '......#####',
    '####.......',
    '...#.......',
    '..#........',
    '.#.........',
    '####.......',
    '...........',
  ],
};

const _keywords = <String, List<String>>{
  'drop': ['HYDRATE', 'WATER', 'DRINK'],
  'dumbbell': ['WORKOUT', 'GYM', 'RUN', 'EXERCISE', 'WALK', 'YOGA', 'TRAIN', 'STRETCH'],
  'pill': ['MED', 'PILL', 'VITAMIN', 'DOSE', 'TABLET'],
  'book': ['STUDY', 'READ', 'WORK', 'FOCUS', 'BOOK', 'CLASS', 'HOMEWORK'],
  'zzz': ['SLEEP', 'BED', 'NAP', 'WIND', 'REST'],
  'coffee': ['COFFEE', 'LUNCH', 'BREAK', 'BREAKFAST', 'TEA', 'DINNER', 'EAT'],
};

/// Accent per illustration (lit '#' pixels when the alarm is on; '+' pixels stay ink).
const _accent = <String, Color>{
  'sunrise': Color(0xFFF97316),
  'coffee': Color(0xFFA16207),
  'sun': Color(0xFFF59E0B),
  'sunset': Color(0xFFE11D48),
  'moon': Color(0xFF6366F1),
  'drop': Color(0xFF0EA5E9),
  'dumbbell': Color(0xFF16A34A),
  'pill': Color(0xFFEF4444),
  'book': Color(0xFF2563EB),
  'zzz': Color(0xFF8B5CF6),
};

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + .05 : lb + .05) / (la > lb ? lb + .05 : la + .05);
}

/// Accent nudged toward ink until it reads clearly on the card colour of any theme.
Color accentFor(String name, Color card, Color ink) {
  var c = _accent[name] ?? ink;
  for (var i = 0; i < 4 && _contrast(c, card) < 2.6; i++) {
    c = Color.lerp(c, ink, .25)!;
  }
  return c;
}

/// Label keyword first, otherwise time of day.
String artFor(Alarm a) {
  final l = a.label.toUpperCase();
  for (final e in _keywords.entries) {
    if (e.value.any(l.contains)) return e.key;
  }
  final h = (a.start % 1440) ~/ 60;
  if (h >= 4 && h < 8) return 'sunrise';
  if (h >= 8 && h < 11) return 'coffee';
  if (h >= 11 && h < 16) return 'sun';
  if (h >= 16 && h < 20) return 'sunset';
  return 'moon';
}

/// Draws the art as an LCD segment grid: unlit cells as faint "ghost" pixels.
/// - First shown: pixels power on in a scattered sweep.
/// - Turned on: colour washes through the lit pixels with a small bounce.
/// - Turned off: colour fades back to ink.
class PixelArt extends StatefulWidget {
  final String name;
  final double size;
  final bool active;
  final Color ink, ghost, accent;
  const PixelArt(
    this.name, {
    super.key,
    required this.size,
    required this.active,
    required this.ink,
    required this.ghost,
    required this.accent,
  });
  @override
  State<PixelArt> createState() => _PixelArtState();
}

class _PixelArtState extends State<PixelArt> with TickerProviderStateMixin {
  late final AnimationController appear = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final AnimationController tint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
    reverseDuration: const Duration(milliseconds: 280),
    value: widget.active ? 1 : 0,
  );
  late final AnimationController bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.12).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: .97).chain(CurveTween(curve: Curves.easeInOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: .97, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
  ]).animate(bounce);
  bool sweeping = false;

  @override
  void didUpdateWidget(PixelArt old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      sweeping = true;
      tint.forward(from: 0).whenComplete(() => sweeping = false);
      bounce.forward(from: 0);
    } else if (!widget.active && old.active) {
      sweeping = false;
      tint.reverse();
    }
  }

  @override
  void dispose() {
    appear.dispose();
    tint.dispose();
    bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: scale,
    child: AnimatedBuilder(
      animation: Listenable.merge([appear, tint]),
      builder: (c, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _PixelPainter(
          _art[widget.name] ?? _art['sun']!,
          Curves.easeOutCubic.transform(appear.value),
          tint.value,
          sweeping,
          widget.ink,
          widget.ghost,
          widget.accent,
        ),
      ),
    ),
  );
}

class _PixelPainter extends CustomPainter {
  final List<String> rows;
  final double v, tint;
  final bool sweep;
  final Color ink, ghost, accent;
  _PixelPainter(this.rows, this.v, this.tint, this.sweep, this.ink, this.ghost, this.accent);

  @override
  void paint(Canvas c, Size s) {
    const n = 11;
    final cell = s.width / n, gap = cell * .16;
    final dim = Paint()..color = ghost;
    final inkP = Paint()..color = ink;
    final uniform = Paint()..color = Color.lerp(ink, accent, tint)!;
    for (var y = 0; y < n; y++) {
      final row = rows[y];
      for (var x = 0; x < n; x++) {
        final ch = x < row.length ? row[x] : '.';
        // Deterministic scatter so pixels light in a pseudo-random order.
        final order = ((x * 7 + y * 13) % 17) / 17 * .6 + (y / n) * .4;
        final r = RRect.fromLTRBR(
          x * cell + gap / 2,
          y * cell + gap / 2,
          (x + 1) * cell - gap / 2,
          (y + 1) * cell - gap / 2,
          Radius.circular(cell * .18),
        );
        if (ch == '.' || v < order) {
          c.drawRRect(r, dim);
        } else if (ch == '+') {
          c.drawRRect(r, inkP);
        } else if (sweep) {
          // Colour washes up from the bottom; each pixel fades in quickly.
          final k = ((tint - (1 - order) * .7) / .3).clamp(0.0, 1.0);
          c.drawRRect(r, Paint()..color = Color.lerp(ink, accent, k)!);
        } else {
          c.drawRRect(r, uniform);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter o) =>
      o.v != v ||
      o.tint != tint ||
      o.sweep != sweep ||
      o.rows != rows ||
      o.ink != ink ||
      o.accent != accent ||
      o.ghost != ghost;
}

/// Human countdown, e.g. "IN 2H 14M", "IN 1D 3H".
String countdown(int mins) {
  if (mins >= 1440) {
    final d = mins ~/ 1440, h = (mins % 1440) ~/ 60;
    return h > 0 ? 'IN ${d}D ${h}H' : 'IN ${d}D';
  }
  return 'IN ${dur(mins)}';
}
