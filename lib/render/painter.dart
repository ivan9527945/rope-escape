import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../game/types.dart';
import 'climber.dart';
import 'details.dart';
import 'draw.dart';
import 'scenery.dart';
import 'sprites.dart';

const stageW = 360.0, baseStageH = 640.0;

/// Stage height for a viewport aspect: at least the classic 640, extended to
/// fill tall phones, capped so very tall ratios stay playable.
double stageHeightFor(Size viewport) =>
    (stageW * viewport.height / viewport.width).clamp(baseStageH, 960.0);

/// Rising platform: hazard rail, pistons, beacon lights and steam.
void drawDeathPlatform(Draw d, ClimbState s) {
  final y = s.deathY - s.camera.y + d.m;
  // Off-screen: the HUD already reports the distance, so nothing is drawn.
  if (y >= d.h + 20) return;
  d.gradientRect(
    0,
    y - 70,
    360,
    120,
    const Color(0x00D37345),
    const Color(0x77D37345),
  );
  for (var i = 0; i < 8; i++) {
    final life = (s.t * 0.6 + i * 0.37) % 1;
    final x = 20 + i * 44 + math.sin(s.t * 2 + i) * 4;
    final yy = y + 20 - life * 70;
    final size = 3 + life * 9;
    d.alpha = 0.3 * (1 - life);
    d.rect(x - size / 2, yy - size / 2, size, size, const Color(0xFFF4F4F8));
  }
  d.alpha = 1;
  d.rect(0, y, 360, d.h, const Color(0xFF35353D));
  // Spike bed: dark socket strip the blades sit in.
  d.rect(0, y, 360, 4, const Color(0xFF1F1F26));
  // Steel blades: alternating tall/short, lit from the left, outlined, with a
  // glint that sweeps across the tips and occasional sparks.
  final glint = (s.t * 110) % 480 - 60;
  for (var i = 0; i < 30; i++) {
    final x = i * 12.0;
    final h = i.isEven ? 15.0 : 10.0;
    final tipX = x + 6, tipY = y - h;
    d.poly([
      [x - 0.5, y + 3],
      [tipX, tipY - 1.5],
      [x + 12.5, y + 3],
    ], const Color(0xFF1F1F26));
    d.poly([
      [x + 1, y + 2],
      [tipX, tipY],
      [tipX, y + 2],
    ], const Color(0xFFF4F4F8));
    d.poly([
      [tipX, tipY],
      [x + 11, y + 2],
      [tipX, y + 2],
    ], const Color(0xFFB0B0BF));
    d.line(
      [
        [tipX, tipY + 1],
        [tipX, y + 2],
      ],
      const Color(0xFF8E8E9C),
      1,
      false,
    );
    d.rect(tipX - 0.5, tipY + 0.5, 1, 1, const Color(0xFFFFFFFF));
    if ((tipX - glint).abs() < 14) {
      d.alpha = 1 - (tipX - glint).abs() / 14;
      d.line(
        [
          [x + 2, y + 1],
          [tipX - 0.5, tipY + 2],
        ],
        const Color(0xFFFFFFFF),
        1,
        false,
      );
      d.alpha = 1;
    }
    // Socket collar and bolt.
    d.rect(x + 2, y + 1, 8, 3, const Color(0xFF53535E));
    d.rect(x + 5, y + 2, 2, 1, const Color(0xFF8E8E9C));
  }
  final sparkFrame = (s.t * 14).floor();
  for (var i = 0; i < 3; i++) {
    final hsh =
        (((sparkFrame + i * 11) * 2654435761) & 0x7FFFFFFF) % 1000 / 1000;
    if (hsh > 0.35) continue;
    final sx = ((sparkFrame * 37 + i * 131) % 30) * 12.0 + 6;
    d.rect(
      sx + (hsh - 0.17) * 10,
      y - 16 - hsh * 10,
      1,
      1,
      i.isEven ? const Color(0xFFFFD27A) : const Color(0xFFFFFFFF),
    );
  }
  // Riveted steel beam under the blades.
  d.rect(0, y + 4, 360, 7, const Color(0xFF53535E));
  d.rect(0, y + 4, 360, 1, const Color(0xFF8E8E9C));
  d.rect(0, y + 10, 360, 1, const Color(0xFF1F1F26));
  for (var x = 4.0; x < 360; x += 12) {
    d.rect(x, y + 6, 2, 2, const Color(0xFFD8D8E2));
    d.rect(x + 1, y + 7, 1, 1, const Color(0xFF35353D));
  }
  // Scrolling hazard chevrons, then the red warning strip.
  d.rect(0, y + 11, 360, 6, const Color(0xFF1F1F26));
  final shift = (s.t * 12) % 16;
  for (var x = -16.0 + shift; x < 360; x += 16) {
    d.poly([
      [x, y + 17],
      [x + 6, y + 11],
      [x + 12, y + 11],
      [x + 6, y + 17],
    ], const Color(0xFFE3C15A));
  }
  d.rect(0, y + 17, 360, 2, const Color(0xFFB94B4C));
  d.rect(0, y + 19, 360, 1, const Color(0xFF1F1F26));
  for (var x = 0.0; x < 360; x += 32) {
    d.sprite('crane1', x, y + 20, frame: 1, w: 32, h: 32);
  }
  for (var x = 16.0; x < 360; x += 72) {
    final stroke = math.sin(s.t * 6 + x) * 3;
    d.rect(x, y + 50, 10, 30, const Color(0xFF24242B));
    d.rect(x + 2, y + 44 + stroke, 6, 10, const Color(0xFF8E8E9C));
    d.rect(x + 3, y + 44 + stroke, 1, 10, const Color(0xFFD8D8E2));
  }
  for (var i = 0; i < 6; i++) {
    final lit = (s.t * 6).floor() % 6 == i;
    d.rect(
      30.0 + i * 60,
      y + 22,
      4,
      4,
      lit ? const Color(0xFFFF5A52) : const Color(0xFF59596A),
    );
    if (lit) {
      d.alpha = 0.35;
      d.rect(26.0 + i * 60, y + 18, 12, 12, const Color(0xFFFF5A52));
      d.alpha = 1;
    }
  }
  for (var side = 0; side < 2; side++) {
    final xx = side == 1 ? 329.0 : 24.0;
    for (var i = 0; i < 7; i++) {
      final yy = y + 10 - ((s.t * 38 + i * 31) % 170);
      d.line(
        [
          [xx - 4, yy + 5],
          [xx, yy],
          [xx + 4, yy + 5],
        ],
        const Color(0xFF943D42),
        2,
      );
    }
  }
}

/// Full-screen post effects: vignette, danger pulse and milestone banner.
void drawOverlays(Draw d, ClimbState s) {
  d.c.drawRect(
    Rect.fromLTWH(0, 0, 360, d.h),
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(180, d.h / 2),
        460 + d.m,
        [const Color(0x00000000), const Color(0x2E000000)],
        [220 / 460, 1],
      ),
  );
  if (s.pressure > 0.45 && s.mode != Mode.menu) {
    final pulse = 0.6 + math.sin(s.pulse * (6 + s.pressure * 6)) * 0.4;
    d.alpha = (s.pressure - 0.45) * 0.55 * pulse;
    d.gradientRect(
      0,
      d.h - 260,
      360,
      260,
      const Color(0x00C94B3C),
      const Color(0xFFC94B3C),
    );
    d.rect(0, 0, 5, d.h, const Color(0xFFD88854));
    d.rect(355, 0, 5, d.h, const Color(0xFFD88854));
    d.alpha = 1;
  }
  if (s.milestoneTime > 0 && s.mode == Mode.playing) {
    final u = s.milestoneTime / 1.8;
    final fade = math.min(1, math.min(u * 4, (1 - u) * 6)).toDouble();
    final rise = (1 - u) * 14;
    d.alpha = fade;
    d.label(
      '${s.milestone * 100} m',
      180,
      250 + d.m - rise,
      const Color(0xFFF6E39A),
      size: 26,
      outline: const Color(0xFF1F1F26),
      outlineWidth: 4,
    );
    d.label(
      'ALTITUDE REACHED',
      180,
      266 + d.m - rise,
      const Color(0xFFEDEDF0),
      size: 8,
    );
    d.alpha = 1;
  }
}

/// Paints the 360-wide logical stage; the height follows the widget size.
class GamePainter extends CustomPainter {
  final ClimbState s;
  final Sprites sprites;
  final PreviewPair? preview;
  final Decor decor;
  final bool reducedMotion;
  final Listenable repaint;
  GamePainter({
    required this.s,
    required this.sprites,
    required this.preview,
    required this.decor,
    required this.reducedMotion,
    required this.repaint,
  }) : super(repaint: repaint);

  static ({double scale, double dx, double dy}) fit(
    Size size, [
    double stageH = baseStageH,
  ]) {
    final scale = math.min(size.width / stageW, size.height / stageH);
    return (
      scale: scale,
      dx: (size.width - stageW * scale) / 2,
      dy: (size.height - stageH * scale) / 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stageH = stageHeightFor(size);
    final f = fit(size, stageH);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF15151C),
    );
    canvas.save();
    canvas.translate(f.dx, f.dy);
    canvas.scale(f.scale);
    canvas.clipRect(Rect.fromLTWH(0, 0, stageW, stageH));
    final d = Draw(canvas, sprites, h: stageH);
    final shake = reducedMotion ? 0.0 : s.shake;
    final ox = shake > 0
        ? (math.sin(s.pulse * 61) * shake * 5).roundToDouble()
        : 0.0;
    final oy = shake > 0
        ? (math.cos(s.pulse * 47) * shake * 4).roundToDouble()
        : 0.0;
    canvas.save();
    canvas.translate(ox, oy);
    drawScenery(d, s);
    drawClimber(d, s, preview, decor);
    drawDetails(d, s);
    drawDeathPlatform(d, s);
    canvas.restore();
    if (shake > 0) {
      d.rect(0, 0, 360, math.max(0.0, oy), const Color(0xFF15151C));
      d.rect(
        0,
        stageH + math.min(0.0, oy),
        360,
        -math.min(0.0, oy),
        const Color(0xFF15151C),
      );
      d.rect(0, 0, math.max(0.0, ox), stageH, const Color(0xFF15151C));
      d.rect(
        360 + math.min(0.0, ox),
        0,
        -math.min(0.0, ox),
        stageH,
        const Color(0xFF15151C),
      );
    }
    drawOverlays(d, s);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}
