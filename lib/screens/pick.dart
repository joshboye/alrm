import 'package:flutter/material.dart';
import '../model.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

const _h = 64.0;

class PickScreen extends StatelessWidget {
  final AppState s;
  const PickScreen(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = s.draft!;
    final isEnd = s.screen == Scr.end;
    final h24 = s.use24h;
    final m = s.pickMin;
    final h = m ~/ 60;
    final mq = MediaQuery.of(context);
    final sl = d.slots, act = d.active;
    final ringsIn = (() {
      final n = DateTime.now();
      final at = DateTime(n.year, n.month, n.day, 0, d.start);
      var diff = at.difference(n).inSeconds;
      if (diff <= 0) diff += 86400;
      return dur(((diff + 59) ~/ 60));
    })();

    final title = isEnd ? 'END TIME' : (d.editingId != null ? 'EDIT ALARM' : 'NEW ALARM');
    final sub = isEnd ? 'STARTS ${fs(d.start, h24)}' : 'RINGS IN $ringsIn';
    Widget digit(String l) => Center(child: Text(l, style: lcd(48, p.lit)));

    final hs = h24 ? h : (h % 12 == 0 ? 12 : h % 12) - 1;
    final wheelsH = (mq.size.height - 520).clamp(192.0, 320.0);
    final bandTop = (wheelsH - _h) / 2;
    final gen = '${s.screen}-${s.wheelGen}';

    return Container(
      color: p.bk,
      padding: EdgeInsets.only(top: mq.padding.top + 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwapText(title, mono(13, p.lit, ls: 1)),
                        const SizedBox(height: 6),
                        t(sub, mono(12, p.dim2, ls: .3), maxLines: 1),
                      ],
                    ),
                  ),
                  if (d.editingId != null && !isEnd)
                    Pressable(
                      onTap: () => _confirmDelete(context),
                      feedback: Haptic.medium,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: t('DELETE', mono(11, p.red, ls: 1)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            height: wheelsH,
            margin: const EdgeInsets.fromLTRB(0, 10, 0, 6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: bandTop,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: h24 ? 240 : 286,
                    height: _h,
                    decoration: BoxDecoration(color: p.band, borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Wheel(
                      key: ValueKey('h$gen$h24'),
                      count: h24 ? 24 : 12,
                      selected: hs,
                      itemH: _h,
                      width: 92,
                      height: wheelsH,
                      builder: (i) => digit(h24 ? pad(i) : pad(i + 1)),
                      onChanged: (i) {
                        final cm = s.pickMin, ch = cm ~/ 60;
                        final nh = h24 ? i : ((i + 1) % 12) + (ch >= 12 ? 12 : 0);
                        if (nh != ch) s.setPick(nh * 60 + cm % 60);
                      },
                    ),
                    const SizedBox(width: 6),
                    Text(':', style: lcd(30, p.lit)),
                    const SizedBox(width: 6),
                    Wheel(
                      key: ValueKey('m$gen'),
                      count: 60,
                      selected: m % 60,
                      itemH: _h,
                      width: 92,
                      height: wheelsH,
                      builder: (i) => digit(pad(i)),
                      onChanged: (i) {
                        final cm = s.pickMin;
                        if (i != cm % 60) s.setPick((cm ~/ 60) * 60 + i);
                      },
                    ),
                    if (!h24) ...[
                      const SizedBox(width: 6),
                      Wheel(
                        key: ValueKey('a$gen'),
                        count: 2,
                        selected: h >= 12 ? 1 : 0,
                        itemH: _h,
                        width: 46,
                        height: wheelsH,
                        scales: const [1, 1],
                        builder: (i) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(i == 0 ? 'AM' : 'PM', style: mono(13, p.lit)),
                        ),
                        onChanged: (i) {
                          final cm = s.pickMin;
                          if ((i == 1) != (cm >= 720)) s.setPick((cm + 720) % 1440);
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Entrance(
                key: ValueKey(isEnd),
                delayMs: 60,
                child: isEnd ? _endSection(p, d, sl) : _startSection(context, p, d, sl, act),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, 26 + mq.padding.bottom * .5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RoundBtn(
                  size: 76,
                  bg: p.s1,
                  label: 'Back',
                  onTap: s.pickBack,
                  child: isEnd ? SvgIcon(Ic.back, size: 18, color: p.lit) : SvgIcon(Ic.close, size: 16, color: p.lit),
                ),
                SwapText(isEnd ? 'CHOOSE END' : 'CHOOSE TIME', mono(13, p.lit, ls: 1)),
                RoundBtn(
                  size: 76,
                  bg: p.cta,
                  label: 'Confirm',
                  feedback: Haptic.medium,
                  onTap: s.pickConfirm,
                  child: SvgIcon(Ic.check, size: 20, color: p.ctaink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final p = context.pal;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              t('DELETE THIS ALARM?', mono(13, p.lit, ls: 1)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _pill(p, 'CANCEL', p.lit, p.s3, () => Navigator.pop(c))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _pill(p, 'DELETE', p.ctaink, p.red, () {
                      Navigator.pop(c);
                      s.delete();
                    }, fill: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(Pal p, String l, Color fg, Color c, VoidCallback onTap, {bool fill = false}) => Material(
    color: fill ? c : Colors.transparent,
    shape: StadiumBorder(side: BorderSide(color: c, width: 1.5)),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: () {
        haptic(fill ? Haptic.heavy : Haptic.light);
        onTap();
      },
      child: SizedBox(height: 48, child: Center(child: t(l, mono(12, fill ? p.lit2 : fg, ls: 1)))),
    ),
  );

  Widget _startSection(BuildContext context, Pal p, Draft d, List<int> sl, List<int> act) {
    final h24 = s.use24h;
    return Column(
      children: [
        Pressable(
          onTap: s.goEnd,
          scale: .97,
          feedback: Haptic.selection,
          child: RBorder(
            radius: 18,
            color: d.hasEnd ? p.band : p.s3b,
            dashed: !d.hasEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    height: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          Container(width: 2, height: 12, color: p.dim),
                          const SizedBox(width: 3),
                        ],
                        Container(width: 2, height: 20, color: p.red),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwapText(d.hasEnd ? 'ENDS ${fs(d.end!, h24)}' : '+ SET END TIME', mono(12, p.lit, ls: .5)),
                        const SizedBox(height: 6),
                        SwapText(
                          d.hasEnd ? 'EVERY ${d.interval} MIN - ${act.length} ALARMS' : 'RING AT INTERVALS',
                          mono(11, p.dim2, ls: .3),
                        ),
                      ],
                    ),
                  ),
                  if (d.hasEnd)
                    Pressable(
                      onTap: s.clearEnd,
                      scale: .8,
                      feedback: Haptic.medium,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: p.ghost, borderRadius: BorderRadius.circular(15)),
                        child: Center(child: SvgIcon(Ic.closeSm, size: 10, color: p.mut)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _opt(p, Ic.note, 'SOUND', d.sound, s.cycleSound),
            const SizedBox(width: 6),
            _opt(p, Ic.vibrate, 'VIBRATE', d.vib ? 'ON' : 'OFF', s.toggleVib),
            const SizedBox(width: 6),
            _opt(p, Ic.repeat, 'REPEAT', daysText(d.days), s.cycleRepeat),
          ],
        ),
        const SizedBox(height: 14),
        _LabelField(s),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _opt(Pal p, Ic ic, String l, String v, VoidCallback onTap) => Expanded(
    child: Pressable(
      onTap: onTap,
      scale: .9,
      feedback: Haptic.selection,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            SvgIcon(ic, size: 18, color: p.lit),
            const SizedBox(height: 7),
            t(l, mono(12, p.lit, ls: .5)),
            const SizedBox(height: 7),
            SizedBox(height: 14, child: Center(child: SwapText(v, mono(11, p.dim2), maxLines: 1))),
          ],
        ),
      ),
    ),
  );

  Widget _endSection(Pal p, Draft d, List<int> sl) {
    final h24 = s.use24h;
    return Column(
      children: [
        RBorder(
          radius: 18,
          color: p.band,
          dashed: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwapText('${fs(d.start, h24)} - ${fs(d.end!, h24)}', mono(20, p.lit, weight: 500)),
                const SizedBox(height: 9),
                SwapText(
                  '${dur(endU(d.start, d.end!) - d.start)} - ${sl.length} ALARMS EVERY ${d.interval} MIN',
                  mono(12, p.dim2, ls: .3),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final (x, l) in const [(30, '+30M'), (60, '+1H'), (120, '+2H'), (180, '+3H')]) ...[
              if (x != 30) const SizedBox(width: 6),
              Expanded(
                child: Pressable(
                  onTap: () => s.addDur(x),
                  scale: .92,
                  feedback: Haptic.selection,
                  child: Container(
                    height: 44,
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(side: BorderSide(color: p.s3, width: 1.5)),
                    ),
                    child: Center(child: t(l, mono(11, p.lit))),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LabelField extends StatelessWidget {
  final AppState s;
  const _LabelField(this.s);

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final label = s.draft?.label ?? '';
    return Pressable(
      onTap: () => _edit(context),
      scale: .97,
      feedback: Haptic.selection,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: p.s1, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            t('LABEL', mono(10, p.dim)),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: SwapText(
                  label.isEmpty ? 'ALARM' : label,
                  mono(12, label.isEmpty ? p.dim : p.lit, ls: .5),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _edit(BuildContext context) {
    final p = context.pal;
    final c = TextEditingController(text: s.draft?.label ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        void done() {
          s.upd((d) => d.label = c.text.trim().toUpperCase());
          haptic(Haptic.light);
          Navigator.pop(ctx);
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: p.bk,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                const SizedBox(height: 16),
                t('LABEL', mono(10, p.dim, ls: 1)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: p.s1,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.band, width: 1.5),
                  ),
                  child: TextField(
                    controller: c,
                    autofocus: true,
                    maxLength: 16,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    cursorColor: p.red,
                    style: mono(20, p.lit, weight: 500, ls: 1),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'ALARM',
                      hintStyle: mono(20, p.dim, weight: 500, ls: 1),
                      counterStyle: mono(10, p.dim),
                    ),
                    onSubmitted: (_) => done(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final q in const ['WAKE UP', 'WORKOUT', 'HYDRATE', 'MEDS', 'STUDY']) ...[
                      Expanded(
                        child: Pressable(
                          onTap: () {
                            c.text = q;
                            c.selection = TextSelection.collapsed(offset: q.length);
                          },
                          scale: .9,
                          feedback: Haptic.selection,
                          child: Container(
                            height: 34,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: ShapeDecoration(
                              shape: StadiumBorder(side: BorderSide(color: p.s3, width: 1.5)),
                            ),
                            child: Center(
                              child: FittedBox(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: t(q, mono(9, p.mut)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Pressable(
                  onTap: done,
                  scale: .97,
                  feedback: Haptic.none,
                  child: Container(
                    height: 52,
                    decoration: ShapeDecoration(color: p.cta, shape: const StadiumBorder()),
                    child: Center(child: t('DONE', mono(12, p.ctaink, ls: 1))),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
