import 'package:flutter/material.dart';
import '../model.dart';
import '../pixel_art.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'settings.dart';

const _cardW = 292.0, _cardGap = 8.0, _pxm = 2.0;

class HomeScreen extends StatefulWidget {
  final AppState s;
  const HomeScreen(this.s, {super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final cards = ScrollController();
  AppState get s => widget.s;

  @override
  void initState() {
    super.initState();
    s.scrollCardTo = _scrollCardTo;
  }

  @override
  void dispose() {
    if (s.scrollCardTo == _scrollCardTo) s.scrollCardTo = null;
    cards.dispose();
    super.dispose();
  }

  void _scrollCardTo(int id) {
    if (!cards.hasClients) return;
    final i = s.sorted.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final x = (i * (_cardW + _cardGap)).clamp(0.0, cards.position.maxScrollExtent);
    cards.animateTo(x, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final barsH = (h - 690).clamp(56.0, 156.0);
    return Container(
      color: p.g,
      child: Stack(
        children: [
          Column(
            children: [
              _panel(context, mq.padding.top, barsH),
              _weekdays(p),
              Expanded(
                child: LayoutBuilder(
                  builder: (c, bc) {
                    final h = (bc.maxHeight - 14).clamp(146.0, 290.0);
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(height: h, child: _cards(p, h)),
                    );
                  },
                ),
              ),
              _bottomBar(context, mq.padding.bottom),
            ],
          ),
          if (s.toast != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 112 + mq.padding.bottom,
              child: Center(child: _Toast(s.toast!, key: ValueKey(s.toast))),
            ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, double top, double barsH) {
    final p = context.pal;
    final nowM = s.nowMin;
    final nowF = fmt(nowM, s.use24h);
    final near = s.nearest(s.finderMin);
    final nx = s.nextUp();
    final issues = s.criticalIssues;
    final line = s.scrubbing && near != null
        ? '${fs(s.finderMin, s.use24h)}  >  ${(near.a.label.isEmpty ? 'ALARM' : near.a.label).toUpperCase()} ${fs(near.t, s.use24h)}'
        : (nx != null ? 'THE NEXT ALARM IN ${dur(s.minsUntil(nx.at))}' : 'NO ALARMS ON');

    final lit = <int>{};
    for (final a in s.alarms) {
      if (!a.on) continue;
      for (final t in a.activeSlots) {
        lit.add((t % 1440) ~/ 30);
      }
    }
    final nowPct = nowM / 1440;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: EdgeInsets.fromLTRB(18, top + 14, 18, 18),
      decoration: BoxDecoration(color: p.bk, borderRadius: BorderRadius.circular(34)),
      child: Column(
        children: [
          if (issues.isNotEmpty)
            Pressable(
              onTap: () => s.engine.fix(issues.first),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: p.red, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: t('! ALARMS MAY NOT RING — TAP TO FIX', mono(10, p.red, ls: .8)),
              ),
            ),
          Pressable(
            onTap: () {},
            onLongPress: () => showSettings(context, s),
            scale: .97,
            feedback: Haptic.none,
            child: LcdTime(nowF.t, size: 88),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 14,
            child: Center(child: SwapText(line, mono(12, p.mut, ls: 1), align: TextAlign.center, maxLines: 1)),
          ),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (c, bc) {
              final w = bc.maxWidth;
              return Column(
                children: [
                  SizedBox(
                    height: 14,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final a in s.alarms.where((a) => a.on))
                          Positioned(
                            top: 5,
                            left: a.start / 1440 * w,
                            child: Container(
                              width: (a.isRange ? (endU(a.start, a.end!).clamp(0, 1440) - a.start) / 1440 * w : 0.0)
                                  .clamp(4.0, w)
                                  .toDouble(),
                              height: 4,
                              decoration: BoxDecoration(color: p.lit, borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                        Positioned(
                          left: nowPct * w - 6,
                          top: 0,
                          child: CustomPaint(size: const Size(12, 9), painter: _Tri(p.red)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: barsH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.linear,
                          builder: (c, v, _) => Row(
                            children: [
                              for (var i = 0; i < 48; i++) ...[
                                if (i > 0) const SizedBox(width: 3),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: Curves.easeOutBack
                                          .transform(((v * 1.9) - i / 48 * .9).clamp(0.0, 1.0))
                                          .clamp(0.0, 1.08),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 450),
                                        curve: Curves.easeOutCubic,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(1),
                                          color: lit.contains(i)
                                              ? ((i + 1) * 30 <= nowM ? p.blitp : p.blit)
                                              : ((i + 1) * 30 <= nowM ? p.bpast : p.bfut),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Positioned(
                          top: -6,
                          bottom: 0,
                          left: nowPct * w - 1,
                          child: _Pulse(child: Container(width: 2, color: p.red)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final l in ['00', '06', '12', '18', '24']) t(l, lcd(9, p.dim)),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _weekdays(Pal p) {
    final today = s.now.weekday - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (var i = 0; i < 7; i++) t(dayNames[i], mono(12, i == today ? p.ink : p.inkd))],
      ),
    );
  }

  Widget _cards(Pal p, double cardH) {
    final items = s.sorted;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: RBorder(
          radius: 18,
          color: p.inkb,
          dashed: true,
          child: Pressable(
            onTap: s.newAlarm,
            scale: .97,
            child: Center(child: t('+ NEW ALARM', mono(12, p.inkm, weight: 500, ls: .5))),
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis != Axis.horizontal) return false;
        if (n is ScrollStartNotification) cardsUser = n.dragDetails != null;
        if (n is ScrollUpdateNotification && cardsUser) _syncFinder(n.metrics.pixels, items);
        if (n is ScrollEndNotification) cardsUser = false;
        return false;
      },
      child: ListView.separated(
        controller: cards,
        scrollDirection: Axis.horizontal,
        physics: const SnapPhysics(extent: _cardW + _cardGap),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: _cardGap),
        itemBuilder: (c, i) => Entrance(
          key: ValueKey('card${items[i].id}'),
          delayMs: 120 + i * 70,
          from: const Offset(36, 0),
          child: _AlarmCard(s, items[i], height: cardH, onLongPress: () => _cardMenu(context, items[i])),
        ),
      ),
    );
  }

  bool cardsUser = false;

  /// Map carousel position -> minute, interpolating between neighbouring cards' start times.
  void _syncFinder(double px, List<Alarm> items) {
    if (items.isEmpty) return;
    final pos = (px / (_cardW + _cardGap)).clamp(0.0, (items.length - 1).toDouble());
    final i = pos.floor(), f = pos - i;
    final a = items[i], b = items[(i + 1).clamp(0, items.length - 1)];
    final m = a.start + (b.start - a.start) * f;
    s.onCardsScrolled(m, items[pos.round()]);
  }

  void _cardMenu(BuildContext context, Alarm a) {
    final p = context.pal;
    final h24 = s.use24h;
    final title = a.isRange ? '${fs(a.start, h24)} - ${fs(a.end!, h24)}' : fs(a.start, h24);
    final sub =
        '${(a.label.isEmpty ? 'ALARM' : a.label).toUpperCase()} · '
        '${a.isRange ? 'EVERY ${a.interval} MIN · ' : ''}${a.days.isEmpty ? 'ONCE' : daysText(a.days)}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) {
        var confirm = false;
        return StatefulBuilder(
          builder: (c, set) {
            Widget row(String l, Color fg, VoidCallback onTap, {Haptic fb = Haptic.selection, Color? bd}) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                onTap: onTap,
                scale: .97,
                feedback: fb,
                child: Container(
                  height: 52,
                  decoration: ShapeDecoration(
                    shape: StadiumBorder(side: BorderSide(color: bd ?? p.s3, width: 1.5)),
                  ),
                  child: Center(child: t(l, mono(12, fg, ls: 1))),
                ),
              ),
            );
            return Container(
              decoration: BoxDecoration(
                color: p.bk,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(c).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: p.dim, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  t(title, mono(20, p.lit, weight: 500)),
                  const SizedBox(height: 8),
                  t(sub, mono(11, p.dim2, ls: .3), maxLines: 2),
                  const SizedBox(height: 20),
                  row('EDIT', p.lit, () {
                    Navigator.pop(c);
                    s.edit(a);
                  }),
                  row('PREVIEW RING', p.lit, () {
                    Navigator.pop(c);
                    s.engine.preview(a.id);
                  }),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: confirm
                        ? Row(
                            key: const ValueKey('confirm'),
                            children: [
                              Expanded(child: row('CANCEL', p.lit, () => set(() => confirm = false))),
                              const SizedBox(width: 8),
                              Expanded(
                                child: row(
                                  'CONFIRM DELETE',
                                  p.red,
                                  () {
                                    Navigator.pop(c);
                                    s.deleteAlarm(a.id);
                                  },
                                  fb: Haptic.none,
                                  bd: p.red,
                                ),
                              ),
                            ],
                          )
                        : KeyedSubtree(
                            key: const ValueKey('del'),
                            child: row('DELETE', p.red, () => set(() => confirm = true), fb: Haptic.medium),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _bottomBar(BuildContext context, double bottom) {
    final p = context.pal;
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 30 + bottom * .5),
      child: Row(
        children: [
          RoundBtn(
            size: 56,
            bg: p.bk,
            label: 'Preview ringing',
            onTap: s.openRing,
            child: SvgIcon(Ic.bell, size: 20, color: p.lit),
          ),
          const SizedBox(width: 8),
          Expanded(child: _Finder(s)),
          const SizedBox(width: 8),
          RoundBtn(
            size: 56,
            bg: p.bk,
            label: 'New alarm',
            onTap: s.newAlarm,
            child: SvgIcon(Ic.plus, size: 18, color: p.lit),
          ),
        ],
      ),
    );
  }
}

class _Tri extends CustomPainter {
  final Color c;
  _Tri(this.c);
  @override
  void paint(Canvas canvas, Size s) => canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close(),
    Paint()..color = c,
  );
  @override
  bool shouldRepaint(_Tri o) => o.c != c;
}

class _Toast extends StatelessWidget {
  final String text;
  const _Toast(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (c, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: p.bk,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: t(text, mono(11, p.lit, ls: .5)),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final AppState s;
  final Alarm a;
  final VoidCallback onLongPress;
  final double height;
  const _AlarmCard(this.s, this.a, {required this.onLongPress, required this.height});

  String _dayWord(DateTime d) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day), day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    return dayNames[d.weekday - 1];
  }

  /// Remaining active slots of a range in today's occurrence.
  int _leftToday() {
    final n = DateTime.now();
    if (a.days.isNotEmpty && !a.days.contains(n.weekday - 1)) return 0;
    var c = 0;
    for (final t in a.activeSlots) {
      final at = DateTime(n.year, n.month, n.day, 0, t);
      final ms = at.millisecondsSinceEpoch;
      if (at.isAfter(n) && ms > a.skipBefore && (a.days.isNotEmpty || ms > a.armedAt)) c++;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isR = a.isRange;
    final h24 = s.use24h;
    final f = fmt(a.start, h24);
    final fe = isR ? fmt(a.end!, h24) : const Fmt('', '');
    final hi = s.highlightId == a.id;
    final sl = a.slots, act = a.activeSlots;
    final full = height >= 200;
    final size = isR ? (full ? 26.0 : 23.0) : (full ? 52.0 : 48.0);
    final ap = isR ? (f.ap == fe.ap ? f.ap : '') : f.ap;
    final label = (a.label.isEmpty ? 'Alarm' : a.label).toUpperCase();
    final line = full
        ? '$label - ${isR ? 'EVERY ${a.interval} MIN' : (a.days.isEmpty ? 'ONCE' : daysText(a.days))}'
        : '$label - ${isR ? 'EVERY ${a.interval} MIN' : daysText(a.days)}';
    final op = a.on ? 1.0 : .4;

    final next = a.on ? a.nextAfter(DateTime.now()) : null;
    final cd = !a.on ? 'OFF' : (next == null ? 'DONE' : countdown(s.minsUntil(next)));
    String when;
    if (!a.on) {
      when = 'TAP TO TURN ON';
    } else if (next == null) {
      when = 'NOTHING LEFT TO RING';
    } else {
      final nm = next.hour * 60 + next.minute;
      final left = isR ? _leftToday() : 0;
      when = isR && left > 0
          ? 'NEXT ${fs(nm, h24)} · $left LEFT TODAY'
          : '${isR ? 'NEXT ' : ''}${_dayWord(next)} ${fs(nm, h24)}';
    }
    final artSize = (height - 170).clamp(46.0, 78.0);
    final art = artFor(a);
    final today = DateTime.now().weekday - 1;

    Widget fade(Widget c) => AnimatedOpacity(duration: const Duration(milliseconds: 220), opacity: op, child: c);

    return Pressable(
      onTap: () {
        haptic(a.on ? Haptic.light : Haptic.medium);
        s.toggle(a);
      },
      onLongPress: onLongPress,
      scale: .965,
      feedback: Haptic.none,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: _cardW,
        decoration: BoxDecoration(color: hi ? p.cardhi : p.card, borderRadius: BorderRadius.circular(18)),
        child: RBorder(
          radius: 18,
          color: hi ? p.ink : p.inkb,
          dashed: !hi,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Time + toggle
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: fade(
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.t, style: lcd(size, p.ink)),
                                if (isR) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(3, 2, 3, 0),
                                    child: Text('→', style: mono(20, p.red, height: 1)),
                                  ),
                                  Text(fe.t, style: lcd(size, p.ink)),
                                ],
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Text(ap, style: mono(9, p.ink, weight: 500)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    fade(Toggle(on: a.on, onTap: () => s.toggle(a))),
                  ],
                ),
                if (full) ...[
                  // Countdown + next ring, with the illustration
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SwapText(cd, mono(22, p.ink, weight: 600, ls: .5), maxLines: 1),
                                const SizedBox(height: 6),
                                SwapText(when, mono(10.5, p.inkm, weight: 500, ls: .4), maxLines: 1),
                              ],
                            ),
                          ),
                          fade(
                            PixelArt(
                              art,
                              size: artSize,
                              active: a.on,
                              ink: p.ink,
                              ghost: p.inks,
                              accent: accentFor(art, hi ? p.cardhi : p.card, p.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Repeat days + sound
                  fade(
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 10),
                      child: Row(
                        children: [
                          if (a.days.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: ShapeDecoration(
                                shape: StadiumBorder(side: BorderSide(color: p.inkb, width: 1.2)),
                              ),
                              child: t('ONE-TIME', mono(9, p.inkm, weight: 500, ls: .5)),
                            )
                          else
                            for (var i = 0; i < 7; i++) ...[
                              if (i > 0) const SizedBox(width: 7),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  t(
                                    'MTWTFSS'[i],
                                    mono(9, a.days.contains(i) ? p.ink : p.inks, weight: i == today ? 700 : 500),
                                  ),
                                  const SizedBox(height: 3),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: a.days.contains(i) ? p.ink : p.inks,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          const Spacer(),
                          SvgIcon(Ic.note, size: 11, color: p.inkm),
                          const SizedBox(width: 4),
                          Flexible(child: t(a.sound, mono(9, p.inkm, weight: 500, ls: .3), maxLines: 1)),
                          if (a.vib) ...[const SizedBox(width: 6), SvgIcon(Ic.vibrate, size: 11, color: p.inkm)],
                        ],
                      ),
                    ),
                  ),
                ],
                // Slot bar + label line
                fade(
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isR) ...[
                          SizedBox(
                            height: 10,
                            child: Row(
                              children: [
                                for (var i = 0; i < sl.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 2),
                                  Expanded(
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200 + i * 12),
                                      decoration: BoxDecoration(
                                        color: a.isSkipped(sl[i]) ? p.inks : p.ink,
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 9),
                        ],
                        Row(
                          children: [
                            Expanded(child: t(line, mono(12, p.inkm, weight: 500, ls: .48), maxLines: 1)),
                            const SizedBox(width: 8),
                            if (isR) t('${act.length}/${sl.length}', mono(12, p.inkm, weight: 500, ls: .48)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal 24h scrubber. Center red line = selected minute; 2px per minute.
class _Finder extends StatefulWidget {
  final AppState s;
  const _Finder(this.s);
  @override
  State<_Finder> createState() => _FinderState();
}

class _FinderState extends State<_Finder> {
  late final ScrollController ctl = ScrollController(initialScrollOffset: widget.s.finderMin * _pxm);
  bool user = false;

  @override
  void initState() {
    super.initState();
    widget.s.scrollFinderTo = _to;
  }

  void _to(double minute) {
    if (!ctl.hasClients || user) return;
    ctl.jumpTo((minute * _pxm).clamp(0.0, ctl.position.maxScrollExtent));
  }

  @override
  void dispose() {
    if (widget.s.scrollFinderTo == _to) widget.s.scrollFinderTo = null;
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = widget.s;
    return Container(
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.bk, borderRadius: BorderRadius.circular(28)),
      child: LayoutBuilder(
        builder: (c, bc) {
          final w = bc.maxWidth;
          return Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification && n.dragDetails != null) user = true;
                  if (n is ScrollUpdateNotification && user) {
                    s.onFinder((n.metrics.pixels / _pxm).round().clamp(0, 1439));
                  }
                  if (n is ScrollEndNotification) user = false;
                  return false;
                },
                child: SingleChildScrollView(
                  controller: ctl,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: CustomPaint(
                    size: Size(1440 * _pxm + w, 56),
                    painter: _FinderPainter(
                      pad: w / 2,
                      h24: s.use24h,
                      p: p,
                      marks: [
                        for (final a in s.alarms.where((a) => a.on))
                          a.isRange
                              ? (
                                  a.start * _pxm,
                                  ((endU(a.start, a.end!).clamp(0, 1440) - a.start) * _pxm).clamp(6.0, 99999.0),
                                )
                              : (a.start * _pxm - 3, 6.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: w / 2 - 1,
                top: 0,
                bottom: 0,
                child: IgnorePointer(child: Container(width: 2, color: p.red)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FinderPainter extends CustomPainter {
  final double pad;
  final bool h24;
  final Pal p;
  final List<(double, double)> marks;
  _FinderPainter({required this.pad, required this.h24, required this.p, required this.marks});

  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i <= 96; i++) {
      final hr = i % 4 == 0, h = (i ~/ 4) % 24;
      final x = pad + i * 30.0;
      final paint = Paint()..color = hr ? p.dim2 : p.s3;
      final len = hr ? 12.0 : 6.0;
      c.drawRect(Rect.fromLTWH(x, 0, 1, len), paint);
      c.drawRect(Rect.fromLTWH(x, s.height - len, 1, len), paint);
      if (hr) {
        final label = h24 ? pad2(h) : '${h % 12 == 0 ? 12 : h % 12}';
        final tp = TextPainter(
          text: TextSpan(text: label, style: lcd(10, p.dim)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(x - tp.width / 2, 22));
      }
    }
    final mp = Paint()..color = p.lit;
    for (final (l, w) in marks) {
      c.drawRRect(RRect.fromLTRBR(pad + l, s.height - 19, pad + l + w, s.height - 16, const Radius.circular(2)), mp);
    }
  }

  static String pad2(int n) => n.toString().padLeft(2, '0');

  @override
  bool shouldRepaint(_FinderPainter o) => true;
}

/// Gentle breathing opacity for the "now" marker.
class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: .55, end: 1.0).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}
