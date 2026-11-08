import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/grid.dart';
import 'screens/home.dart';
import 'screens/pick.dart';
import 'screens/ring.dart';
import 'state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final s = AppState();
  runApp(App(s));
  s.init();
}

/// Rebuilds the MaterialApp only when the theme changes; everything else
/// rebuilds below the Navigator (see [_Host]) so scrolling stays smooth.
class App extends StatefulWidget {
  final AppState s;
  const App(this.s, {super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  AppState get s => widget.s;
  late String theme = s.theme;

  void _l() {
    if (s.theme != theme) setState(() => theme = s.theme);
  }

  @override
  void initState() {
    super.initState();
    s.addListener(_l);
  }

  @override
  void dispose() {
    s.removeListener(_l);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palettes[theme] ?? palettes['crimson']!;
    return PalScope(
      pal: p,
      child: MaterialApp(
        title: 'alrm',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: p.bk,
          splashFactory: InkRipple.splashFactory,
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: p.red,
            selectionColor: p.band,
            selectionHandleColor: p.red,
          ),
        ),
        builder: (c, child) => MediaQuery(
          // Fixed-size LCD layout: ignore OS font scaling to keep the design intact.
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        ),
        home: ListenableBuilder(
          listenable: s,
          builder: (c, _) => PalScope(pal: palettes[s.theme] ?? p, child: Root(s)),
        ),
      ),
    );
  }
}

class Root extends StatelessWidget {
  final AppState s;
  const Root(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final light = s.screen == Scr.home || s.screen == Scr.ring;
    Widget body;
    if (!s.loaded) {
      body = const SizedBox.shrink(key: ValueKey('loading'));
    } else {
      body = switch (s.screen) {
        Scr.home => HomeScreen(s, key: const ValueKey('home')),
        Scr.pick || Scr.end => PickScreen(s, key: ValueKey('pick-${s.screen}')),
        Scr.grid => GridScreen(s, key: const ValueKey('grid')),
        Scr.ring => RingScreen(s, key: const ValueKey('ring')),
      };
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (light ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.light).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: light ? p.g : p.bk,
        systemNavigationBarIconBrightness: light && p.g.computeLuminance() > .5 ? Brightness.dark : Brightness.light,
      ),
      child: PopScope(
        canPop: s.screen == Scr.home,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          switch (s.screen) {
            case Scr.pick || Scr.end:
              s.pickBack();
            case Scr.grid:
              s.gridBack();
            default:
          }
        },
        child: Scaffold(
          backgroundColor: p.bk,
          resizeToAvoidBottomInset: false,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: const Cubic(.2, .8, .2, 1),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .015), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}
