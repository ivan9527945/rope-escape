import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../audio/game_audio.dart';
import '../render/climber.dart';
import '../render/sprites.dart';
import 'rope_core.dart';
import 'types.dart';

const resumeCountdown = 1.5;

/// How long an assisted jump waits for a catch to line up before giving up.
const jumpAssistWindow = 0.45;

/// Snapshot of the simulation for the widget layer, refreshed ~10×/s.
class GameView {
  final Mode mode;
  final int score, wear, gap, combo;
  final String notice, reason;
  final bool shield, ready, assetsLoaded, armed, jumpReady, jumpQueued;
  final String? assetError;
  final double brake, time, countdown;
  final RunStats stats;
  const GameView({
    required this.mode,
    required this.score,
    required this.wear,
    required this.gap,
    required this.combo,
    required this.notice,
    required this.reason,
    required this.shield,
    required this.ready,
    required this.assetsLoaded,
    required this.armed,
    required this.jumpReady,
    required this.jumpQueued,
    required this.assetError,
    required this.brake,
    required this.time,
    required this.countdown,
    required this.stats,
  });
}

/// Owns the fixed-step loop, the simulation, prediction cache, audio and haptics.
class GameController extends ChangeNotifier {
  ClimbState s = createClimb()..mode = Mode.menu;
  final Sprites sprites = Sprites();
  final GameAudio audio = GameAudio();
  final Decor decor = Decor();
  final ValueNotifier<int> frame = ValueNotifier(0);
  PreviewPair? preview;
  bool sound = true;
  bool haptics = true;
  bool reducedMotion = false;
  late final Ticker _ticker;
  bool get tickerActive => _ticker.isActive;
  Duration _last = Duration.zero;
  double _accumulator = 0, _emitClock = 0;
  int _lastTick = -1;
  double _jumpBuffer = 0;
  bool _wasReady = false;
  late GameView view = _snapshot();

  GameController() {
    _ticker = Ticker(_onTick)..start();
    sprites.load().then((_) => _emit());
    audio.init().then((_) => _syncAudio());
  }

  void _onTick(Duration now) {
    var dt = (now - _last).inMicroseconds / 1e6;
    if (_last == Duration.zero) dt = 0;
    _last = now;
    _accumulator += math.min(dt, 0.05);
    while (_accumulator >= 1 / 60) {
      update(1 / 60);
      _accumulator -= 1 / 60;
    }
    frame.value++;
  }

  void start() {
    if (!sprites.loaded) return;
    s = createClimb(DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF)
      ..armed = false;
    audio.reset();
    audio.ui('click');
    preview = null;
    _jumpBuffer = 0;
    decor.reset();
    _syncAudio();
    _emit();
  }

  void menu() {
    s = createClimb()..mode = Mode.menu;
    _jumpBuffer = 0;
    audio.ui('click');
    _syncAudio();
    _emit();
  }

  void pause() {
    if (s.mode == Mode.playing) {
      s.mode = Mode.paused;
      audio.ui('pause');
    } else if (s.mode == Mode.paused) {
      s.mode = Mode.playing;
      // Returning from pause gives a short frozen countdown before input resumes.
      s.countdown = resumeCountdown;
      _lastTick = -1;
      audio.ui('resume');
    }
    _syncAudio();
    _emit();
  }

  void action(RopeAction a) {
    ropeAction(s, a);
    preview = null;
    _emit();
  }

  /// Whether releasing right now would catch a rope above the current one.
  bool get jumpReady {
    final p = preview, held = s.attached;
    if (p == null || held == null) return false;
    final t = p.flight.target;
    return p.flight.result == 'catch' && t != null && t.id > held;
  }

  bool get jumpQueued => _jumpBuffer > 0;

  bool _catchAhead() {
    final held = s.attached;
    if (held == null) return false;
    final f = predictClimb(s);
    final t = f.target;
    return f.result == 'catch' && t != null && t.id > held;
  }

  /// Jump with timing assist: if no catch is lined up yet the jump is queued
  /// for a short window and fires on the first frame one appears. A swipe
  /// passes [assist] false and releases immediately.
  void jump({bool assist = true}) {
    if (s.mode != Mode.playing || s.countdown > 0 || s.attached == null) {
      return;
    }
    if (!assist || _catchAhead()) {
      _jumpBuffer = 0;
      action(RopeAction.jump);
      return;
    }
    _jumpBuffer = jumpAssistWindow;
    _emit();
  }

  void setSound(bool enabled) {
    sound = enabled;
    _syncAudio();
    notifyListeners();
  }

  void _syncAudio() => audio.setState(
    enabled: sound,
    mode: s.mode,
    tension: math.max(s.pressure, math.min(0.6, s.t / 120)),
  );

  void update(double dt) {
    if (s.mode == Mode.menu) {
      s.t += dt;
      return;
    }
    final before = s.mode, countdownBefore = s.countdown;
    stepClimb(s, dt);
    if (countdownBefore > 0) {
      final step = (s.countdown / (resumeCountdown / 3)).ceil();
      if (s.countdown <= 0) {
        audio.ui('go');
      } else if (step != _lastTick) {
        _lastTick = step;
        audio.ui('tick');
      }
      _emit();
      return;
    }
    _syncAudio();
    for (final e in s.events) {
      audio.effect(e);
      _haptic(e);
    }
    s.events.clear();
    if (before != Mode.over && s.mode == Mode.over) audio.ui('over');
    if (_jumpBuffer > 0) {
      if (s.mode != Mode.playing || s.attached == null) {
        _jumpBuffer = 0;
      } else if (_catchAhead()) {
        _jumpBuffer = 0;
        ropeAction(s, RopeAction.jump);
        preview = null;
      } else {
        _jumpBuffer -= dt;
        if (_jumpBuffer <= 0) {
          s.notice = 'NOT YET · jump when the ring turns green';
          s.noticeTime = 1.2;
        }
      }
    }
    if (s.attached != null &&
        math.sin(s.theta).abs() < 0.15 &&
        s.omega.abs() > 1.8) {
      audio.effect('swing');
    }
    if (s.mode == Mode.playing &&
        s.countdown <= 0 &&
        (preview == null || (s.t - preview!.t).abs() > 0.065)) {
      preview = PreviewPair(
        s.t,
        predictClimb(s),
        s.attached != null
            ? predictClimb(s, release: false, seconds: 0.7)
            : Prediction.empty,
      );
    }
    final ready = jumpReady;
    if (ready && !_wasReady && haptics) HapticFeedback.selectionClick();
    _wasReady = ready;
    _emitClock += dt;
    if (_emitClock > 0.1 || before != s.mode || ready != view.jumpReady) {
      _emitClock = 0;
      _emit();
    }
  }

  void _haptic(String e) {
    if (!haptics) return;
    switch (e) {
      case 'catch':
        HapticFeedback.lightImpact();
      case 'block':
      case 'snap':
      case 'pickup':
        HapticFeedback.mediumImpact();
      case 'death':
        HapticFeedback.heavyImpact();
    }
  }

  GameView _snapshot() {
    final r = s.held;
    return GameView(
      mode: s.mode,
      score: s.score,
      wear: math.max(0, (r?.wear ?? 0).round()),
      gap: math.max(0, ((s.deathY - s.player.y) / 3).round()),
      combo: s.combo,
      notice: s.noticeTime > 0
          ? s.notice
          : !s.armed
          ? 'The floor waits · make a move to start'
          : s.pressure > 0.65
          ? 'DANGER! Floor closing in · jump now'
          : s.deathSpeed > 80
          ? '↑ The floor is speeding up'
          : '↑ The floor keeps rising · keep moving',
      reason: s.reason,
      shield: s.shield > 0,
      ready: s.attached != null,
      assetsLoaded: sprites.loaded,
      armed: s.armed,
      jumpReady: jumpReady,
      jumpQueued: _jumpBuffer > 0,
      assetError: sprites.error,
      brake: s.brake,
      time: s.t,
      countdown: s.countdown,
      stats: s.stats.clone(),
    );
  }

  void _emit() {
    view = _snapshot();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    audio.dispose();
    frame.dispose();
    super.dispose();
  }
}
