import 'package:flutter/material.dart';
import '../model.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class GridScreen extends StatelessWidget {
  final AppState s;
  const GridScreen(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = s.draft!;
    final h24 = s.use24h;
    final mq = MediaQuery.of(context);
    final sl = d.slots, act = d.active;
    final groups = <int, List<int>>{};
    for (final x in sl) {
      groups.putIfAbsent(x ~/ 60, () => []).add(x);
    }
    final keys = groups.keys.toList()..sort();

    Widget ival(String l, bool on, bool lcdFont, VoidCallback onTap) => Expanded(
      child: Pressable(
        onTap: onTap,
        scale: .88,
        feedback: Haptic.selection,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 42,
          decoration: BoxDecoration(
            color: on ? p.band : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? p.band : p.s3, width: 1.5),
          ),
          child: Center(child: Text(l, style: lcdFont ? lcd(15, on ? p.lit2 : p.mut) : mono(11, on ? p.lit2 : p.mut))),
        ),
      ),
    );

    return Container(
      color: p.bk,
      padding: EdgeInsets.only(top: mq.padding.top + 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                t(d.editingId != null ? 'EDIT INTERVALS' : 'INTERVALS', mono(13, p.lit, ls: 1)),
                const SizedBox(height: 8),
                t('${fs(d.start, h24)} - ${fs(d.end!, h24)}', mono(14, p.dim2, weight: 500)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final x in presets) ...[
                      ival(
                        '$x',
                        !d.custom && d.interval == x,
                        true,
                        () => s.upd((d) {
                          d.interval = x;
                          d.custom = false;
                        }),
                      ),
                      const SizedBox(width: 5),
                    ],
                    ival('CUST', d.custom, false, () => s.upd((d) => d.custom = true)),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !d.custom
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(color: p.s1, borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                t('EVERY', mono(11, p.dim)),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 96,
                                  height: 132,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 44,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: p.band,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      Wheel(
                                        key: ValueKey('c${s.wheelGen}'),
                                        count: 120,
                                        selected: (d.interval - 1).clamp(0, 119),
                                        itemH: 44,
                                        width: 96,
                                        height: 132,
                                        scales: const [1, .82, .72],
                                        opacities: const [1, .4, .15],
                                        builder: (i) => Center(child: Text('${i + 1}', style: lcd(22, p.lit))),
                                        onChanged: (i) => s.upd((d) => d.interval = i + 1),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                t('MIN', mono(11, p.dim)),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwapText('${pad(act.length)}/${pad(sl.length)}', lcd(26, p.lit)),
                            const SizedBox(height: 8),
                            t('ALARMS ON - TAP A TIME TO SKIP', mono(11, p.dim2, ls: .3)),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        transitionBuilder: (c, a) => ScaleTransition(
                          scale: a,
                          child: FadeTransition(opacity: a, child: c),
                        ),
                        child: act.length < sl.length
                            ? Pressable(
                                key: const ValueKey('allon'),
                                onTap: () => s.upd((d) => d.skipped = []),
                                feedback: Haptic.medium,
                                child: Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: ShapeDecoration(
                                    shape: StadiumBorder(side: BorderSide(color: p.band, width: 1.5)),
                                  ),
                                  child: Center(child: t('ALL ON', mono(10, p.lit))),
                                ),
                              )
                            : const SizedBox(key: ValueKey('none')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
              itemCount: keys.length,
              itemBuilder: (c, gi) {
                final k = keys[gi], hh = k % 24;
                final label = h24 ? pad(hh) : pad(hh % 12 == 0 ? 12 : hh % 12);
                return Entrance(
                  key: ValueKey('row$k'),
                  delayMs: (gi * 45).clamp(0, 400),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: p.s2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 40,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: lcd(11, p.dim)),
                                if (!h24) ...[
                                  const SizedBox(height: 4),
                                  Text(hh < 12 ? 'AM' : 'PM', style: mono(8, p.dim)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (c, bc) {
                              final cw = (bc.maxWidth - 5 * 5) / 6;
                              return Wrap(
                                spacing: 5,
                                runSpacing: 5,
                                children: [for (final x in groups[k]!) _cell(p, x, d.isSkipped(x), cw)],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 26 + mq.padding.bottom * .5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RoundBtn(
                  size: 76,
                  bg: p.s1,
                  label: 'Back',
                  onTap: s.gridBack,
                  child: SvgIcon(Ic.back, size: 18, color: p.lit),
                ),
                SwapText(act.isNotEmpty ? 'SET ${act.length} ALARMS' : 'ALL SKIPPED', mono(13, p.lit, ls: 1)),
                RoundBtn(
                  size: 76,
                  bg: p.cta,
                  label: 'Save',
                  feedback: Haptic.medium,
                  onTap: act.isEmpty ? () => s.showToast('ALL TIMES SKIPPED') : s.save,
                  child: SvgIcon(Ic.check, size: 20, color: p.ctaink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(Pal p, int x, bool skipped, double w) {
    final on = !skipped;
    return Pressable(
      onTap: () => s.toggleSlot(x),
      scale: .86,
      feedback: on ? Haptic.light : Haptic.selection,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: w,
        height: 50,
        decoration: BoxDecoration(
          color: on ? p.band : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? p.band : p.ghost, width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(':${pad(x % 60)}', style: lcd(14, on ? p.lit2 : p.s3b)),
            ),
            Transform.rotate(
              angle: -20 * 3.14159 / 180,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: on ? 0 : 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (c, v, _) => Container(
                  width: w * .7 * v,
                  height: 1.5,
                  color: p.red.withValues(alpha: .9 * v),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
