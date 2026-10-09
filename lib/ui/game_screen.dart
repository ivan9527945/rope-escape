import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../game/types.dart';
import '../render/painter.dart';
import 'panels.dart';
import 'records.dart';
import 'theme.dart';

/// Swipe classification in logical stage pixels; a swipe releases, it does not aim.
RopeAction? ropeGesture(Offset start, Offset end, int elapsedMs) {
  final dx = end.dx - start.dx, dy = end.dy - start.dy;
  final d = math.sqrt(dx * dx + dy * dy);
  if (d < 12) return elapsedMs < 600 ? RopeAction.pump : null;
  if (d < 22) return null;
  if (dy > 20 && dy > dx.abs() * 0.8) return RopeAction.lower;
  return RopeAction.jump;
}

class GameScreen extends StatefulWidget {
  final GameController? controller;
  const GameScreen({super.key, this.controller});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameController game = widget.controller ?? GameController();
  Records records = Records();
  bool help = false;
  ({bool record, int previous})? result;
  int? _pointer;
  Offset? _from;
  DateTime? _downAt;
  bool _cancelled = false;
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
    Records.load().then((r) => setState(() => records = r));
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

  @override
  void dispose() {
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
          // any sub-pixel gap at the edges.
          return SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
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
                          return;
                        }
                        _pointer = e.pointer;
                        _from = e.localPosition;
                        _downAt = DateTime.now();
                        _cancelled = false;
                      },
                      onPointerUp: (e) {
                        if (_pointer != e.pointer) return;
                        final from = _from, at = _downAt;
                        _pointer = null;
                        if (!_cancelled &&
                            from != null &&
                            at != null &&
                            game.s.mode == Mode.playing) {
                          final a = ropeGesture(
                            from,
                            e.localPosition,
                            DateTime.now().difference(at).inMilliseconds,
                          );
                          if (a != null) game.action(a);
                        }
                      },
                      onPointerCancel: (_) => _pointer = null,
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
                        child: Controls(onAction: game.action),
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
