import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rope_escape/game/controller.dart';
import 'package:rope_escape/game/types.dart';
import 'package:rope_escape/render/painter.dart';
import 'package:rope_escape/ui/game_screen.dart';
import 'package:rope_escape/ui/panels.dart';
import 'package:rope_escape/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rope_core_test.dart' show planRope;

// Drives the real widget tree with the real sprites and fonts, saving PNGs of
// every screen to output/screens/ so the mobile layout can be reviewed.
Future<void> _save(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('stage')),
  );
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('output/screens/$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}

/// Crops the stage image around the climber for close inspection of the sprite.
Future<void> _saveCrop(
  WidgetTester tester,
  GameController game,
  String name,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('stage')),
  );
  final image = await boundary.toImage(pixelRatio: 3);
  final fit = GamePainter.fit(
    const Size(390, 844),
    stageHeightFor(const Size(390, 844)),
  );
  final px = (game.s.player.x * fit.scale + fit.dx) * 3;
  final py = ((game.s.player.y - game.s.camera.y) * fit.scale + fit.dy) * 3;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = 160.0;
  canvas.drawImageRect(
    image,
    Rect.fromCenter(center: Offset(px, py), width: size, height: size),
    const Rect.fromLTWH(0, 0, size, size),
    Paint(),
  );
  final crop = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final bytes = await crop.toByteData(format: ui.ImageByteFormat.png);
  await File(
    'output/screens/$name.png',
  ).writeAsBytes(bytes!.buffer.asUint8List());
}

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(microseconds: 16667));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final loader = FontLoader('DotGothic16')
      ..addFont(rootBundle.load('assets/fonts/dotgothic16.ttf'));
    await loader.load();
  });

  testWidgets(
    'menu, play, pause, countdown and result screens render',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late final GameController game;
      await tester.runAsync(() async {
        game = GameController();
        await game.sprites.ready;
      });
      expect(game.sprites.loaded, isTrue, reason: game.sprites.error);
      debugPrint('sprites ready');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: RepaintBoundary(
            key: const Key('stage'),
            child: GameScreen(controller: game),
          ),
        ),
      );
      await _frames(tester, 30);
      debugPrint('menu frames pumped');
      await tester.runAsync(() => _save(tester, 'menu'));
      debugPrint('menu saved');

      await tester.tap(find.text('START CLIMB'));
      await _frames(tester, 2);
      expect(game.s.mode, Mode.playing);
      await _frames(tester, 25);
      expect(find.text('HOW TO CLIMB'), findsOneWidget);
      expect(game.s.armed, isFalse);
      final floorBefore = game.s.deathY;
      await _frames(tester, 60);
      expect(
        game.s.deathY,
        floorBefore,
        reason: 'floor waits for the first move',
      );
      await tester.runAsync(() => _save(tester, 'hint'));
      for (var n = 0; n < 5; n++) {
        final plan = planRope(game.s);
        expect(plan, isNotNull, reason: 'reachable rope on lap $n');
        for (var i = 0; i < plan!.lowers; i++) {
          game.action(RopeAction.lower);
        }
        for (var i = 0; i < plan.pumps; i++) {
          game.action(RopeAction.pump);
        }
        await _frames(tester, (plan.wait * 60).round());
        game.action(RopeAction.jump);
        await _frames(tester, plan.frames);
        expect(game.s.attached, plan.state.attached);
      }
      expect(game.s.stats.catches, greaterThanOrEqualTo(5));
      final hint = tester.widget<StartHint>(find.byType(StartHint));
      expect(
        hint.visible,
        isFalse,
        reason: 'primer hides after the first action',
      );
      await _frames(tester, 8);
      await tester.runAsync(() => _save(tester, 'play'));
      await tester.runAsync(() => _saveCrop(tester, game, 'player-zoom'));
      debugPrint('play saved');

      await tester.tap(find.text('Ⅱ'));
      await _frames(tester, 20);
      expect(game.s.mode, Mode.paused);
      expect(find.text('RESUME'), findsOneWidget);
      await tester.runAsync(() => _save(tester, 'pause'));
      debugPrint('pause saved');

      await tester.tap(find.text('RESUME'));
      await _frames(tester, 18);
      expect(game.s.mode, Mode.playing);
      expect(game.s.countdown, greaterThan(0));
      final frozenY = game.s.player.y;
      game.action(RopeAction.pump);
      await _frames(tester, 12);
      expect(game.s.player.y, frozenY, reason: 'world frozen during countdown');
      await tester.runAsync(() => _save(tester, 'countdown'));
      debugPrint('countdown saved');
      await _frames(tester, 70);
      expect(game.s.countdown, 0);

      for (var i = 0; i < 90 * 60 && game.s.mode != Mode.over; i++) {
        await tester.pump(const Duration(microseconds: 16667));
      }
      expect(game.s.mode, Mode.over);
      await _frames(tester, 80);
      expect(find.text('PLAY AGAIN'), findsOneWidget);
      expect(find.textContaining('NEW RECORD'), findsOneWidget);
      await tester.runAsync(() => _save(tester, 'result'));
      debugPrint('result saved');

      await tester.tap(find.text('PLAY AGAIN'));
      await _frames(tester, 2);
      expect(game.s.mode, Mode.playing);
      expect(game.s.score, lessThan(10));
      expect(game.s.stats.catches, 0);
      // Stop the controller's ticker before the test tears the tree down.
      await tester.pumpWidget(const SizedBox());
      game.dispose();
      expect(game.tickerActive, isFalse);
    },
  );
}
