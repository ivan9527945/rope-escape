import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/controller.dart';
import '../game/types.dart';
import '../render/painter.dart';
import 'intro.dart';
import 'panels.dart';
import 'records.dart';
import 'theme.dart';

enum StageGesture { tap, swipeDown, swipe }

/// Classifies a pointer down/up pair in logical stage pixels. A tap is an
/// assisted jump, a downward swipe lowers, any other swipe jumps at once.
/// Holding still is handled separately as a pump.
StageGesture? stageGesture(Offset start, Offset end) {
  final dx = end.dx - start.dx, dy = end.dy - start.dy;
  final d = math.sqrt(dx * dx + dy * dy);
  if (d < 18) return StageGesture.tap;
  if (d < 26) return null;
  if (dy > 20 && dy > dx.abs() * 0.8) return StageGesture.swipeDown;
  return StageGesture.swipe;
}

/// Holding a finger still this long starts pumping; it repeats while held.
const holdPumpDelay = Duration(milliseconds: 320);

class GameScreen extends StatefulWidget {
  final GameController? controller;

  /// Plays the launch animation over the menu once; tests turn it off.
  final bool showIntro;
  const GameScreen({super.key, this.controller, this.showIntro = true});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameController game = widget.controller ?? GameController();
  Records records = Records();
  bool help = false;
  late bool intro = widget.showIntro;
  ({bool record, int previous})? result;
  int? _pointer;
  Offset? _from, _last;
  bool _cancelled = false, _pumped = false;
  Timer? _hold, _keyPump;
  Mode _lastMode = Mode.menu;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game.reducedMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    game.addListener(_onView);
    HardwareKeyboard.instance.addHandler(_onKey);
    Records.load().then((r) => setState(() => records = r));
  }

  /// Keyboard controls for desktop and web builds: Space/↑ jump, ↓ lower,
  /// holding ←/→ or Shift pumps, Esc/P pauses, Enter starts.
  bool _onKey(KeyEvent e) {
    final k = e.logicalKey;
    final pumpKey =
        k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.shiftLeft ||
        k == LogicalKeyboardKey.shiftRight ||
        k == LogicalKeyboardKey.keyC;
    if (e is KeyUpEvent) {
      if (pumpKey) {
        _keyPump?.cancel();
        _keyPump = null;
      }
      return false;
    }
    if (e is! KeyDownEvent) return false;
    final mode = game.s.mode;
    if (k == LogicalKeyboardKey.enter) {
      if (mode == Mode.menu || mode == Mode.over) _start();
      return true;
    }
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.keyP) {
      if (help) {
        setState(() => help = false);
      } else if (mode == Mode.playing || mode == Mode.paused) {
        game.pause();
      }
      return true;
    }
    if (mode != Mode.playing) return false;
    if (k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyW ||
        k == LogicalKeyboardKey.keyZ) {
      game.jump();
      return true;
    }
    if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.keyS ||
        k == LogicalKeyboardKey.keyX) {
      game.action(RopeAction.lower);
      return true;
    }
    if (pumpKey && _keyPump == null) {
      game.action(RopeAction.pump);
      _keyPump = Timer.periodic(holdPumpDelay, (t) {
        if (game.s.mode != Mode.playing) return;
        game.action(RopeAction.pump);
      });
      return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && game.s.mode == Mode.playing) {
      game.pause();
    }
  }

  void _onView() {
    final v = game.view;
    if (v.mode != _lastMode) {
      if (v.mode == Mode.playing) {
        result = null;
      }
      if (v.mode == Mode.over && result == null) _commitRun(v);
      _lastMode = v.mode;
    }
    setState(() {});
  }

  void _commitRun(GameView v) {
    final previous = records.best;
    final record = v.score > previous;
    records
      ..best = math.max(previous, v.score)
      ..runs += 1
      ..bestCombo = math.max(records.bestCombo, v.stats.maxCombo)
      ..bestTime = math.max(records.bestTime, v.time)
      ..total += v.score;
    records.save();
    result = (record: record, previous: previous);
    if (record && v.score > 0) game.audio.ui('record');
  }

  void _start() {
    setState(() => help = false);
    game.start();
  }

  void _openHelp() {
    if (game.s.mode == Mode.playing) game.pause();
    setState(() => help = true);
  }

  void _startHold() {
    _hold?.cancel();
    _pumped = false;
    _hold = Timer.periodic(holdPumpDelay, (t) {
      final from = _from, last = _last;
      if (from == null || game.s.mode != Mode.playing) {
        t.cancel();
        return;
      }
      // A finger that already travelled is a swipe in progress, not a hold.
      if (!_pumped && last != null && (last - from).distance >= 18) {
        t.cancel();
        return;
      }
      _pumped = true;
      game.action(RopeAction.pump);
    });
  }

  void _endHold() {
    _hold?.cancel();
    _hold = null;
  }

  @override
  void dispose() {
    _endHold();
    _keyPump?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    game.removeListener(_onView);
    if (widget.controller == null) game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = game.view;
    final playing =
        v.mode == Mode.playing || v.mode == Mode.paused || v.mode == Mode.dying;
    final countdown = v.mode == Mode.playing && v.countdown > 0;
    final overlay = v.mode == Mode.paused || v.mode == Mode.over || help;
    return Scaffold(
      backgroundColor: Pal.shell,
      body: LayoutBuilder(
        builder: (context, c) {
          // The stage keeps its 360 logical width and grows in height to fill
          // the device, so no letterbox bars appear on tall phones.
          final stageH = stageHeightFor(Size(c.maxWidth, c.maxHeight));
          final scale = math.min(c.maxWidth / stageW, c.maxHeight / stageH);
          final pad = MediaQuery.paddingOf(context);
          final inset = EdgeInsets.only(
            top: pad.top / scale,
            bottom: pad.bottom / scale,
          );
          // Tight constraints make FittedBox scale the stage up; cover removes
          // any sub-pixel gap at the edges. Viewports wider than the stage
          // (iPad, 3:4) would lose the HUD and controls to the crop, so they
          // get pillarboxed instead.
          final wide = c.maxWidth / c.maxHeight > stageW / stageH + 0.01;
          return SizedBox.expand(
            child: FittedBox(
              fit: wide ? BoxFit.contain : BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: stageW,
                height: stageH,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Listener(
                      onPointerDown: (e) {
                        if (v.mode != Mode.playing) return;
                        if (_pointer != null) {
                          _cancelled = true;
                          _endHold();
                          return;
                        }
                        _pointer = e.pointer;
                        _from = e.localPosition;
                        _last = e.localPosition;
                        _cancelled = false;
                        _startHold();
                      },
                      onPointerMove: (e) {
                        if (_pointer == e.pointer) _last = e.localPosition;
                      },
                      onPointerUp: (e) {
                        if (_pointer != e.pointer) return;
                        final from = _from, pumped = _pumped;
                        _pointer = null;
                        _endHold();
                        if (_cancelled ||
                            pumped ||
                            from == null ||
                            game.s.mode != Mode.playing) {
                          return;
                        }
                        switch (stageGesture(from, e.localPosition)) {
                          case StageGesture.tap:
                            game.jump();
                          case StageGesture.swipeDown:
                            game.action(RopeAction.lower);
                          case StageGesture.swipe:
                            game.jump(assist: false);
                          case null:
                            break;
                        }
                      },
                      onPointerCancel: (_) {
                        _pointer = null;
                        _endHold();
                      },
                      child: ValueListenableBuilder<int>(
                        valueListenable: game.frame,
                        builder: (_, _, _) => CustomPaint(
                          painter: GamePainter(
                            s: game.s,
                            sprites: game.sprites,
                            preview: game.preview,
                            decor: game.decor,
                            reducedMotion: game.reducedMotion,
                            repaint: game.frame,
                          ),
                          size: Size(stageW, stageH),
                        ),
                      ),
                    ),
                    if (v.mode == Mode.menu && !help)
                      MenuPanel(
                        view: v,
                        records: records,
                        inset: inset,
                        onStart: _start,
                        onHelp: _openHelp,
                      ),
                    if (playing)
                      Hud(
                        view: v,
                        sound: game.sound,
                        onPause: game.pause,
                        onSound: () => game.setSound(!game.sound),
                        inset: inset,
                      ),
                    if (v.mode == Mode.playing && !countdown)
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16 + inset.bottom,
                        child: Controls(
                          onAction: game.action,
                          onJump: game.jump,
                          jumpReady: v.jumpReady,
                          jumpQueued: v.jumpQueued,
                        ),
                      ),
                    if (v.mode == Mode.playing && !countdown)
                      StartHint(visible: !v.armed),
                    if (countdown) CountdownOverlay(countdown: v.countdown),
                    if (overlay)
                      Container(
                        color: v.mode == Mode.paused && !help
                            ? const Color(0xB86B6B7A)
                            : const Color(0xCC6B6B7A),
                        padding: EdgeInsets.fromLTRB(
                          18,
                          30 + inset.top,
                          18,
                          18 + inset.bottom,
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: help
                                  ? HelpPanel(
                                      key: const ValueKey('help'),
                                      paused: v.mode == Mode.paused,
                                      onStart: _start,
                                      onClose: () =>
                                          setState(() => help = false),
                                    )
                                  : v.mode == Mode.paused
                                  ? PausePanel(
                                      key: const ValueKey('pause'),
                                      view: v,
                                      sound: game.sound,
                                      onResume: game.pause,
                                      onRestart: _start,
                                      onHelp: _openHelp,
                                      onMenu: game.menu,
                                      onSound: () => game.setSound(!game.sound),
                                    )
                                  : ResultPanel(
                                      key: const ValueKey('result'),
                                      view: v,
                                      isRecord:
                                          (result?.record ?? false) &&
                                          v.score > 0,
                                      onAgain: _start,
                                      onMenu: game.menu,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    if (intro)
                      IntroOverlay(
                        sprites: game.sprites,
                        reducedMotion: game.reducedMotion,
                        onDone: () => setState(() => intro = false),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
