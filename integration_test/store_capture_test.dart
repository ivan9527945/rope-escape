import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rope_escape/game/controller.dart';
import 'package:rope_escape/game/rope_core.dart';
import 'package:rope_escape/game/types.dart';
import 'package:rope_escape/ui/game_screen.dart';
import 'package:rope_escape/ui/theme.dart';

// Plays a real run on a device or simulator for App Store captures. It writes
// the current phase to <Documents>/capture-phase.txt so tool/store_capture.sh
// can take simulator screenshots and trim the recording at the right moments.
// Run with: flutter test integration_test/store_capture_test.dart -d <udid>
/// Frames to wait (0, 6, … 60) before a jump catches a rope above [ropeId],
/// optionally after performing [first]; null when no such moment exists.
int? _jumpWait(ClimbState live, int ropeId, {RopeAction? first}) {
  for (var w = 0; w <= 60; w += 6) {
    final q = live.clone();
    if (first != null) ropeAction(q, first);
    for (var i = 0; i < w; i++) {
      stepClimb(q, 1 / 60);
    }
    if (q.mode != Mode.playing || q.attached != ropeId) break;
    final flight = predictClimb(q);
    final target = flight.target;
    if (flight.result == 'catch' && target != null && target.id > ropeId) {
      return w;
    }
  }
  return null;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store capture run', (tester) async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final phaseFile = File(
      '${(await getApplicationDocumentsDirectory()).path}/capture-phase.txt',
    );
    Future<void> wait(double seconds) =>
        tester.pump(Duration(milliseconds: (seconds * 1000).round()));
    Future<void> phase(String name, double hold) async {
      await phaseFile.writeAsString(name, flush: true);
      await wait(hold);
    }

    final game = GameController();
    await tester.pumpWidget(
      MaterialApp(
        title: 'Rope Escape',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: GameScreen(controller: game, showIntro: false),
      ),
    );
    final boot = Stopwatch()..start();
    while (!game.sprites.loaded ||
        (!game.audio.ready && boot.elapsed.inSeconds < 20)) {
      await wait(0.1);
    }
    await wait(1.0);
    await phase('menu', 3.0);
    await tester.tap(find.text('START CLIMB'));
    await phase('hint', 2.0);

    var lastPump = -1.0, lastLower = -1.0, stuckSince = -1.0;
    var lowersOnRope = 0, ropeId = -1;
    var pausedOnce = false, captured = false, captured2 = false;
    final clock = Stopwatch()..start();
    // Act for ~45 s (the preview clip is the first 30 s, the pause comes
    // after it), then stop moving so the floor ends the run and the result
    // panel can be captured.
    while (game.s.mode != Mode.over && clock.elapsed.inSeconds < 110) {
      final s = game.s;
      final acting = clock.elapsed.inSeconds < 45;
      if (acting &&
          s.mode == Mode.playing &&
          s.countdown <= 0 &&
          s.attached != null) {
        if (s.attached != ropeId) {
          ropeId = s.attached!;
          lowersOnRope = 0;
          stuckSince = s.t;
        }
        // Short lookahead with the real integrator: does a jump now or within
        // a second catch a higher rope? If not, would a pump or a lower first?
        final now = _jumpWait(s, ropeId);
        if (now == 0) {
          await tester.tap(find.text('JUMP ↑'));
          stuckSince = s.t;
        } else if (now == null) {
          final canPump = s.t - lastPump > 0.3 && (s.held?.wear ?? 0) > 20;
          if (canPump && _jumpWait(s, ropeId, first: RopeAction.pump) != null) {
            lastPump = s.t;
            await tester.tap(find.text('PUMP'));
          } else if (lowersOnRope < 3 &&
              s.t - lastLower > 0.6 &&
              _jumpWait(s, ropeId, first: RopeAction.lower) != null) {
            lastLower = s.t;
            lowersOnRope++;
            await tester.tap(find.text('LOWER ↓'));
          } else if (canPump && s.omega.abs() < 2.4 && s.t - lastPump > 0.45) {
            lastPump = s.t;
            await tester.tap(find.text('PUMP'));
          } else if (s.t - stuckSince > 3 && lowersOnRope < 3) {
            lastLower = s.t;
            lowersOnRope++;
            await tester.tap(find.text('LOWER ↓'));
          }
        }
        if (!captured && s.score > 90 && s.combo >= 2) {
          captured = true;
          await phase('play', 1.2);
        }
        if (!captured2 && s.score > 350 && s.combo >= 4) {
          captured2 = true;
          await phase('play2', 1.2);
        }
        if (!pausedOnce && clock.elapsed.inSeconds >= 33) {
          pausedOnce = true;
          await tester.tap(find.text('Ⅱ'));
          await phase('pause', 3.0);
          await tester.tap(find.text('RESUME'));
          await phase('countdown', 0.7);
          await phaseFile.writeAsString('resume', flush: true);
        }
      }
      await wait(0.08);
    }
    if (!captured) await phase('play', 0.5);
    await wait(0.8);
    await phase('result', 3.0);
    await phaseFile.writeAsString('done', flush: true);
    await wait(1.0);
    // Tear down audio first so no position-updater frame callback outlives
    // the widget tree, which the live binding reports as a test failure.
    await game.audio.dispose();
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
