import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

// ---------------- Icons (ported 1:1 from the design's inline SVGs) ----------------

enum Ic { bell, plus, close, closeSm, back, check, note, vibrate, repeat, arrow }

class SvgIcon extends StatelessWidget {
  final Ic icon;
  final double size;
  final Color color;
  const SvgIcon(this.icon, {super.key, required this.size, required this.color});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _IconPainter(icon, color));
}

class _IconPainter extends CustomPainter {
  final Ic icon;
  final Color color;
  _IconPainter(this.icon, this.color);

  @override
  void paint(Canvas c, Size s) {
    final (vb, w) = switch (icon) {
      Ic.bell => (20.0, 1.6),
      Ic.plus => (18.0, 1.8),
      Ic.close => (16.0, 2.0),
      Ic.closeSm => (10.0, 1.6),
      Ic.back => (18.0, 2.0),
      Ic.check => (20.0, 2.4),
      Ic.note || Ic.vibrate || Ic.repeat => (18.0, 1.5),
      Ic.arrow => (22.0, 2.2),
    };
    c.scale(s.width / vb);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (icon) {
      case Ic.bell:
        path
          ..moveTo(5, 14)
          ..lineTo(5, 9)
          ..arcToPoint(const Offset(15, 9), radius: const Radius.circular(5))
          ..lineTo(15, 14)
          ..lineTo(16.5, 15.5)
          ..lineTo(3.5, 15.5)
          ..close()
          ..moveTo(8.5, 17.5)
          ..lineTo(11.5, 17.5);
      case Ic.plus:
        path
          ..moveTo(9, 2)
          ..lineTo(9, 16)
          ..moveTo(2, 9)
          ..lineTo(16, 9);
      case Ic.close:
        path
          ..moveTo(3, 3)
          ..lineTo(13, 13)
          ..moveTo(13, 3)
          ..lineTo(3, 13);
      case Ic.closeSm:
        path
          ..moveTo(1.5, 1.5)
          ..lineTo(8.5, 8.5)
          ..moveTo(8.5, 1.5)
          ..lineTo(1.5, 8.5);
      case Ic.back:
        path
          ..moveTo(11, 3)
          ..lineTo(5, 9)
          ..lineTo(11, 15);
      case Ic.check:
        path
          ..moveTo(4, 10.5)
          ..lineTo(8, 14.5)
          ..lineTo(16, 5.5);
      case Ic.note:
        path
          ..addOval(Rect.fromCircle(center: const Offset(5.5, 13.5), radius: 2.2))
          ..addOval(Rect.fromCircle(center: const Offset(12.5, 11), radius: 2.2))
          ..moveTo(7.7, 13.5)
          ..lineTo(7.7, 3.5)
          ..lineTo(14.7, 2)
          ..lineTo(14.7, 11);
      case Ic.vibrate:
        path
          ..addRRect(RRect.fromLTRBR(6, 2.5, 12, 15.5, const Radius.circular(1.5)))
          ..moveTo(3, 6)
          ..lineTo(3, 12)
          ..moveTo(15, 6)
          ..lineTo(15, 12);
      case Ic.repeat:
        path
          ..moveTo(3, 8)
          ..lineTo(3, 7)
          ..arcToPoint(const Offset(6, 4), radius: const Radius.circular(3))
          ..lineTo(15, 4)
          ..lineTo(12.5, 1.5)
          ..moveTo(15, 10)
          ..lineTo(15, 11)
          ..arcToPoint(const Offset(12, 14), radius: const Radius.circular(3))
          ..lineTo(3, 14)
          ..lineTo(5.5, 16.5);
      case Ic.arrow:
        path
          ..moveTo(5, 11)
          ..lineTo(17, 11)
          ..moveTo(12, 6)
          ..lineTo(17, 11)
          ..lineTo(12, 16);
    }
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_IconPainter o) => o.icon != icon || o.color != color;
}

// ---------------- Round button ----------------

class RoundBtn extends StatelessWidget {
  final double size;
  final Color bg;
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final Haptic feedback;
  const RoundBtn({
    super.key,
    required this.size,
    required this.bg,
    required this.child,
    this.onTap,
    this.label,
    this.feedback = Haptic.light,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onTap,
      scale: .9,
      feedback: feedback,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Center(child: child),
      ),
    ),
  );
}

enum Haptic { none, selection, light, medium, heavy }

void haptic(Haptic h) {
  switch (h) {
    case Haptic.selection:
      HapticFeedback.selectionClick();
    case Haptic.light:
      HapticFeedback.lightImpact();
    case Haptic.medium:
      HapticFeedback.mediumImpact();
    case Haptic.heavy:
      HapticFeedback.heavyImpact();
    case Haptic.none:
  }
}

/// Springy press-scale + haptic tap. Used for every tappable surface.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Haptic feedback;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = .95,
    this.feedback = Haptic.light,
  });
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;
  void _set(bool v) {
    if (down != v && mounted) setState(() => down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null ? null : (_) => _set(true),
    onTapUp: (_) => _set(false),
    onTapCancel: () => _set(false),
    onTap: widget.onTap == null
        ? null
        : () {
            haptic(widget.feedback);
            widget.onTap!();
          },
    onLongPress: widget.onLongPress == null
        ? null
        : () {
            _set(false);
            haptic(Haptic.medium);
            widget.onLongPress!();
          },
    child: AnimatedScale(
      scale: down ? widget.scale : 1,
      duration: Duration(milliseconds: down ? 90 : 260),
      curve: down ? Curves.easeOut : Curves.elasticOut,
      child: widget.child,
    ),
  );
}

/// One-shot fade + slide-in, optionally delayed (for staggered lists).
class Entrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Offset from;
  const Entrance({super.key, required this.child, this.delayMs = 0, this.from = const Offset(0, 14)});
  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  late final Animation<double> a = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) c.forward();
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: a,
    builder: (_, child) => Opacity(
      opacity: a.value,
      child: Transform.translate(offset: widget.from * (1 - a.value), child: child),
    ),
    child: widget.child,
  );
}

/// Text that cross-fades + slides when its value changes.
class SwapText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? align;
  final int? maxLines;
  const SwapText(this.text, this.style, {super.key, this.align, this.maxLines});
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, a) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .35), end: Offset.zero).animate(a),
        child: child,
      ),
    ),
    layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
    child: Text(
      text,
      key: ValueKey(text),
      style: style,
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    ),
  );
}

// ---------------- LCD digits with ghost "88:88" ----------------

class LcdTime extends StatelessWidget {
  final String text;
  final double size;
  const LcdTime(this.text, {super.key, required this.size});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: [
          Text('88:88', style: lcd(size, p.ghost).copyWith(letterSpacing: 2)),
          Positioned(
            left: 0,
            top: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
              layoutBuilder: (cur, prev) => Stack(children: [...prev, ?cur]),
              child: Text(text, key: ValueKey(text), style: lcd(size, p.lit).copyWith(letterSpacing: 2)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Dashed / solid rounded border ----------------

class RBorder extends StatelessWidget {
  final double radius, width;
  final Color color;
  final bool dashed;
  final Widget child;
  final Color? fill;
  const RBorder({
    super.key,
    required this.radius,
    required this.color,
    required this.dashed,
    required this.child,
    this.width = 1.5,
    this.fill,
  });
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _RBorderPainter(radius, width, color, dashed, fill), child: child);
}

class _RBorderPainter extends CustomPainter {
  final double r, w;
  final Color c;
  final bool dashed;
  final Color? fill;
  _RBorderPainter(this.r, this.w, this.c, this.dashed, this.fill);
  @override
  void paint(Canvas canvas, Size s) {
    final rr = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(r));
    if (fill != null) canvas.drawRRect(rr, Paint()..color = fill!);
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    final inner = rr.deflate(w / 2);
    if (!dashed) {
      canvas.drawRRect(inner, p);
      return;
    }
    final path = Path()..addRRect(inner);
    const dash = 4.5, gap = 3.0;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_RBorderPainter o) => o.r != r || o.w != w || o.c != c || o.dashed != dashed || o.fill != fill;
}

// ---------------- On/off toggle (44×26) ----------------

class Toggle extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  const Toggle({super.key, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      toggled: on,
      label: 'Toggle alarm',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          haptic(on ? Haptic.light : Haptic.medium);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 26,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: on ? p.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: p.ink, width: 1.5),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: const Cubic(.3, .7, .3, 1),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(color: on ? p.g : p.ink, borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Snapping horizontal physics for alarm cards ----------------

class SnapPhysics extends ScrollPhysics {
  final double extent;
  const SnapPhysics({required this.extent, super.parent});
  @override
  SnapPhysics applyTo(ScrollPhysics? ancestor) => SnapPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics pos, double velocity) {
    if ((velocity <= 0 && pos.pixels <= pos.minScrollExtent) || (velocity >= 0 && pos.pixels >= pos.maxScrollExtent)) {
      return super.createBallisticSimulation(pos, velocity);
    }
    var page = pos.pixels / extent;
    if (velocity < -toleranceFor(pos).velocity) {
      page -= .5;
    } else if (velocity > toleranceFor(pos).velocity) {
      page += .5;
    }
    final target = (page.roundToDouble() * extent).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if ((target - pos.pixels).abs() < toleranceFor(pos).distance) return null;
    return ScrollSpringSimulation(spring, pos.pixels, target, velocity, tolerance: toleranceFor(pos));
  }

  @override
  bool get allowImplicitScrolling => false;
}

// ---------------- Vertical snapping wheel column ----------------

/// Piecewise-linear lookup: v[0] at distance 0, v[1] at 1, ... clamped to last.
double lerpSteps(List<double> v, double d) {
  if (d <= 0) return v.first;
  if (d >= v.length - 1) return v.last;
  final i = d.floor(), f = d - i;
  return v[i] + (v[i + 1] - v[i]) * f;
}

/// Flat snapping wheel. Each item's scale/opacity follow the live scroll offset
/// (pure transforms, no relayout) so scrolling stays at full frame rate.
class Wheel extends StatefulWidget {
  final int count;
  final int selected;
  final double itemH;
  final double width;
  final double height;
  final Widget Function(int i) builder;
  final ValueChanged<int> onChanged;
  final List<double> scales;
  final List<double> opacities;
  const Wheel({
    super.key,
    required this.count,
    required this.selected,
    required this.itemH,
    required this.width,
    required this.height,
    required this.builder,
    required this.onChanged,
    this.scales = const [1, 34 / 48, 30 / 48, 28 / 48],
    this.opacities = const [1, .55, .3, .15],
  });
  @override
  State<Wheel> createState() => _WheelState();
}

class _WheelState extends State<Wheel> {
  late final FixedExtentScrollController ctl = FixedExtentScrollController(initialItem: widget.selected);
  late int cur = widget.selected;
  bool programmatic = false;

  @override
  void didUpdateWidget(Wheel old) {
    super.didUpdateWidget(old);
    if (widget.selected != cur && ctl.hasClients && !ctl.position.isScrollingNotifier.value) {
      _animateTo(widget.selected);
    }
  }

  Future<void> _animateTo(int i) async {
    cur = i;
    programmatic = true;
    await ctl.animateToItem(i, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    programmatic = false;
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: ListWheelScrollView.useDelegate(
      controller: ctl,
      itemExtent: widget.itemH,
      diameterRatio: 1000,
      physics: const FixedExtentScrollPhysics(parent: BouncingScrollPhysics()),
      onSelectedItemChanged: (i) {
        if (programmatic) return;
        cur = i;
        HapticFeedback.selectionClick();
        widget.onChanged(i);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.count,
        builder: (c, i) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ctl.animateToItem(i, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic),
          child: AnimatedBuilder(
            animation: ctl,
            builder: (c, child) {
              final off = ctl.hasClients ? ctl.offset : cur * widget.itemH;
              final d = (i * widget.itemH - off).abs() / widget.itemH;
              return Opacity(
                opacity: lerpSteps(widget.opacities, d),
                child: Transform.scale(scale: lerpSteps(widget.scales, d), child: child),
              );
            },
            child: SizedBox(
              width: widget.width,
              child: RepaintBoundary(child: widget.builder(i)),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Small text helper.
Widget t(String s, TextStyle st, {TextAlign? align, int? maxLines}) =>
    Text(s, style: st, textAlign: align, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null);
