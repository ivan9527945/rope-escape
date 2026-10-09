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

/// Snapshot of the simulation for the widget layer, refreshed ~10×/s.
class GameView {
  final Mode mode;
  final int score, wear, gap, combo;
  final String notice, reason;
  final bool shield, ready, assetsLoaded, armed;
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
    decor.reset();
    _syncAudio();
    _emit();
  }

  void menu() {
    s = createClimb()..mode = Mode.menu;
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
    _emitClock += dt;
    if (_emitClock > 0.1 || before != s.mode) {
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
