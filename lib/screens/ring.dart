import 'package:flutter/material.dart';
import '../model.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class RingScreen extends StatefulWidget {
  final AppState s;
  const RingScreen(this.s, {super.key});
  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> with TickerProviderStateMixin {
  late final AnimationController blink = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat();
  late final AnimationController breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  late final AnimationController nudge = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();
  double dragX = 0;
  bool dragging = false, done = false, armed = false;

  @override
  void dispose() {
    blink.dispose();
    breathe.dispose();
    nudge.dispose();
    super.dispose();
  }

  /// Idle "slide me" hint: a short nudge to the right at the start of each cycle.
  double get _nudgeX {
    if (dragging || dragX > 0 || done) return 0;
    final v = nudge.value;
    if (v > .3) return 0;
    final k = 1 - ((v / .15) - 1).abs();
    return 16 * Curves.easeOut.transform(k.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = widget.s;
    final ri = s.ringInfo;
    final mq = MediaQuery.of(context);
    final slot = ri?.slot ?? s.ring?.slot ?? s.nowMin;
    final f = fmt(slot, s.use24h);
    final isR = ri?.alarm.isRange ?? false;
    final label = (ri == null || ri.alarm.label.isEmpty ? 'Alarm' : ri.alarm.label).toUpperCase();
    final breath = CurvedAnimation(parent: breathe, curve: Curves.easeInOut);

    return PopScope(
      canPop: false,
      child: Container(
        color: p.g,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              padding: EdgeInsets.fromLTRB(20, mq.padding.top + 26, 20, 30),
              decoration: BoxDecoration(color: p.bk, borderRadius: BorderRadius.circular(34)),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: blink,
                    builder: (c, _) => Opacity(
                      opacity: blink.value < .5 ? 1 : .15,
                      child: t(ri?.preview == true ? 'PREVIEW' : 'ALARM', mono(12, p.red, ls: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Entrance(delayMs: 80, child: t(label, mono(16, p.lit, ls: 1))),
                  const SizedBox(height: 46),
                  ScaleTransition(scale: Tween(begin: 1.0, end: 1.035).animate(breath), child: LcdTime(f.t, size: 98)),
                  const SizedBox(height: 14),
                  t(f.ap.isEmpty ? ' ' : f.ap, mono(12, p.mut)),
                  if (isR && ri != null) ...[
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 70,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < ri.act.length; i++) ...[
                            if (i > 0) const SizedBox(width: 3),
                            Expanded(
                              child: Entrance(
                                delayMs: 200 + (i * 25).clamp(0, 600),
                                from: const Offset(0, 20),
                                child: i == ri.i
                                    ? FadeTransition(
                                        opacity: Tween(begin: .45, end: 1.0).animate(breath),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(1),
                                            color: p.red,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(1),
                                          color: i < ri.i ? p.bpast : p.lit,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        t('${ri.i + 1} OF ${ri.act.length}', mono(10, p.mut, ls: .5)),
                        t(ri.next != null ? 'NEXT ${fs(ri.next!, s.use24h)}' : 'LAST ONE', mono(10, p.mut, ls: .5)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 30 + mq.padding.bottom * .5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Entrance(
                    delayMs: 150,
                    child: Pressable(
                      onTap: done
                          ? null
                          : () {
                              setState(() => done = true);
                              s.snooze();
                            },
                      scale: .96,
                      feedback: Haptic.medium,
                      child: Container(
                        height: 62,
                        decoration: ShapeDecoration(color: p.bk, shape: const StadiumBorder()),
                        child: Center(child: t('SNOOZE - 9 MIN', mono(13, p.lit, ls: 1))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Entrance(delayMs: 230, child: _slider(p, s)),
                  if (isR && ri != null && ri.rest.isNotEmpty)
                    Entrance(
                      delayMs: 310,
                      child: Pressable(
                        onTap: done
                            ? null
                            : () {
                                setState(() => done = true);
                                s.skipRest();
                              },
                        feedback: Haptic.medium,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 22, bottom: 12),
                          child: Center(
                            child: Text(
                              'SKIP REMAINING ${ri.rest.length} IN THIS RANGE',
                              style: mono(
                                11,
                                p.ink,
                                ls: .5,
                              ).copyWith(decoration: TextDecoration.underline, decorationColor: p.ink),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(Pal p, AppState s) => LayoutBuilder(
    builder: (c, bc) {
      final max = bc.maxWidth - 76;
      final dur = dragging ? Duration.zero : const Duration(milliseconds: 320);
      const curve = Cubic(.3, .7, .3, 1);
      return Container(
        height: 76,
        decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(38)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Progress fill trailing the thumb.
            Positioned(
              left: 6,
              top: 6,
              bottom: 6,
              child: AnimatedContainer(
                duration: dur,
                curve: curve,
                width: 64 + dragX,
                decoration: BoxDecoration(color: p.g.withValues(alpha: .16), borderRadius: BorderRadius.circular(32)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Opacity(
                opacity: (1 - dragX / (max * .7)).clamp(0.0, 1.0),
                child: t('SLIDE TO STOP', mono(12, p.dim, ls: 1)),
              ),
            ),
            AnimatedBuilder(
              animation: nudge,
              builder: (c, child) =>
                  AnimatedPositioned(duration: dur, curve: curve, left: 6 + dragX + _nudgeX, top: 6, child: child!),
              child: GestureDetector(
                onHorizontalDragStart: (_) {
                  haptic(Haptic.light);
                  setState(() => dragging = true);
                },
                onHorizontalDragUpdate: (e) {
                  final nx = (dragX + e.delta.dx).clamp(0.0, max);
                  final nowArmed = nx >= max * .85;
                  if (nowArmed != armed) haptic(nowArmed ? Haptic.medium : Haptic.selection);
                  setState(() {
                    dragX = nx;
                    armed = nowArmed;
                  });
                },
                onHorizontalDragEnd: (_) {
                  if (dragX >= max * .85 && !done) {
                    haptic(Haptic.heavy);
                    setState(() {
                      dragX = max;
                      dragging = false;
                      done = true;
                    });
                    Future.delayed(const Duration(milliseconds: 220), s.stop);
                  } else {
                    setState(() {
                      dragX = 0;
                      dragging = false;
                      armed = false;
                    });
                  }
                },
                child: AnimatedScale(
                  scale: dragging ? 1.06 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: p.g, borderRadius: BorderRadius.circular(32)),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                        child: armed
                            ? SvgIcon(Ic.check, key: const ValueKey('c'), size: 22, color: p.ink)
                            : SvgIcon(Ic.arrow, key: const ValueKey('a'), size: 22, color: p.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
