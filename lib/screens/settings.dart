import 'package:flutter/material.dart';
import '../model.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Opened by long-pressing the home clock.
void showSettings(BuildContext context, AppState s) {
  s.refreshHealth();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ListenableBuilder(
      listenable: s,
      builder: (c, _) => PalScope(pal: palettes[s.theme]!, child: _Settings(s)),
    ),
  );
}

class _Settings extends StatelessWidget {
  final AppState s;
  const _Settings(this.s);

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget label(String l) =>
        Padding(padding: const EdgeInsets.only(bottom: 10, top: 18), child: t(l, mono(10, p.dim, ls: 1)));
    Widget chip(String l, bool on, VoidCallback onTap, {Color? swatch}) => Expanded(
      child: Pressable(
        onTap: onTap,
        scale: .9,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (swatch != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              t(l, mono(11, on ? p.lit2 : p.mut)),
            ],
          ),
        ),
      ),
    );
    Widget gap(List<Widget> xs) => Row(
      children: [
        for (var i = 0; i < xs.length; i++) ...[if (i > 0) const SizedBox(width: 6), xs[i]],
      ],
    );

    final checks = <(String, String, String)>[
      ('notifications', 'NOTIFICATIONS', 'Needed to show the alarm'),
      ('fullScreen', 'FULL-SCREEN ALARM', 'Takes over the lock screen'),
      ('exact', 'EXACT ALARMS', 'Rings on the exact minute'),
      ('battery', 'UNRESTRICTED BATTERY', 'Recommended on Xiaomi/Samsung/OnePlus'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: p.bk,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
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
          const SizedBox(height: 14),
          t('SETTINGS', mono(13, p.lit, ls: 1)),
          label('THEME'),
          gap([
            for (final n in themeNames)
              chip(n.toUpperCase(), s.theme == n, () => s.setSettings(theme: n), swatch: palettes[n]!.red),
          ]),
          label('CLOCK'),
          gap([
            chip('12H', !s.use24h, () => s.setSettings(use24h: false)),
            chip('24H', s.use24h, () => s.setSettings(use24h: true)),
          ]),
          label('DEFAULT INTERVAL (MIN)'),
          gap([for (final x in presets) chip('$x', s.defaultInterval == x, () => s.setSettings(defaultInterval: x))]),
          label('RELIABILITY'),
          for (final (k, title, sub) in checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Pressable(
                scale: .97,
                onTap: s.health[k] == true ? null : () => s.engine.fix(k),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: p.s1, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            t(title, mono(11, p.lit, ls: .5)),
                            const SizedBox(height: 4),
                            t(sub, mono(10, p.dim2)),
                          ],
                        ),
                      ),
                      t(s.health[k] == true ? 'OK' : 'FIX >', mono(11, s.health[k] == true ? p.mut : p.red, ls: .5)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
