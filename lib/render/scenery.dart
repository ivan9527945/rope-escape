import 'dart:math' as math;
import 'dart:ui';

import '../game/types.dart';
import 'draw.dart';

/// Vertical industrial canyon with continuous, bounded distant parallax.
void drawScenery(Draw d, ClimbState s) {
  final cy = s.camera.y - d.m, h = d.h, m = d.m;
  final altitude = (-s.camera.y / 9000).clamp(0.0, 1.0);
  d.gradientRect(
    0,
    0,
    360,
    h,
    altitude > 0.5 ? const Color(0xFFC4C4D2) : const Color(0xFFBABAC8),
    const Color(0xFFA9A9B8),
  );
  // Distant light shafts drift slowly; very low alpha keeps them atmospheric.
  d.alpha = 0.07;
  for (var i = 0; i < 3; i++) {
    final x = ((i * 140 + s.t * 4 - cy * 0.02) % 520) - 80;
    d.poly([
      [x, 0],
      [x + 70, 0],
      [x + 180, h],
      [x + 90, h],
    ], const Color(0xFFFFFFFF));
  }
  // Pixel clouds on a slow parallax band.
  d.alpha = 0.35;
  for (var i = 0; i < 5; i++) {
    final w = 46.0 + (i % 3) * 22;
    final x = (((i * 97 + s.t * (5 + i)) % 440) + 440) % 440 - 60;
    final y = ((i * 131 - cy * 0.05) % (h + 60) + (h + 60)) % (h + 60) - 30;
    d.rect(x, y, w, 6, const Color(0xFFD6D6E0));
    d.rect(x + 8, y - 4, w - 16, 4, const Color(0xFFD6D6E0));
    d.rect(x + 4, y + 6, w - 8, 3, const Color(0xFFC3C3CF));
  }
  d.alpha = 1;
  d.sprite('mothership', 220 - s.player.x * 0.025, 65 + m);
  // Distant skyline remains quiet behind the playable, darker cables.
  for (final layer in const [
    ('background', 0.08, 255.0),
    ('midground1', 0.17, 345.0),
    ('midground2', 0.26, 465.0),
  ]) {
    final (name, factor, base) = layer;
    final y = base + m + _tanh(-s.camera.y / 2400) * factor * 350;
    d.alpha = name == 'background' ? 0.6 : 0.8;
    d.sprite(name, -(s.player.x - 180) * factor - 60, y, scale: 1.15);
  }
  d.alpha = 1;
  // Cross cables between façades give the canyon depth without blocking play.
  d.alpha = 0.18;
  const cablePeriod = 420.0;
  final firstCable = ((cy * 0.45 - h) / cablePeriod).floor();
  final cables = (h / cablePeriod).ceil() + 3;
  for (var n = firstCable; n < firstCable + cables; n++) {
    final y = n * cablePeriod - cy * 0.45 + 120;
    final sag = 26.0 + (n & 1) * 10;
    final path = Path()
      ..moveTo(0, y)
      ..quadraticBezierTo(180, y + sag, 360, y - 8);
    d.c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF2A2A31).withValues(alpha: 0.18),
    );
    for (var x = 60.0; x < 360; x += 80) {
      final t = x / 360;
      final yy =
          (1 - t) * (1 - t) * y + 2 * (1 - t) * t * (y + sag) + t * t * (y - 8);
      d.rect(x, yy, 2, 4, const Color(0xFF2A2A31));
    }
  }
  d.alpha = 1;
  // Narrow façades frame the route; all playable space stays unobstructed.
  for (final side in const [0, 1]) {
    final left = side == 0;
    final x = left ? -44.0 : 338.0;
    const period = 256.0;
    const w = 66.0;
    final first = ((cy * 0.62 - h) / period).floor();
    final count = (h / period).ceil() + 5;
    for (var n = first; n < first + count; n++) {
      final y = (n * period - cy * 0.62).roundToDouble();
      d.rect(x, y, w, period, const Color(0xFF35353D));
      for (var yy = 0.0; yy < period; yy += 16) {
        for (var xx = 0.0; xx < w; xx += 16) {
          d.sprite(
            side == 1 ? 'wall2' : 'wall1',
            x + xx,
            y + yy,
            frame: n & 1,
            w: 16,
            h: 16,
          );
        }
      }
      for (var yy = 24.0; yy < period; yy += 48) {
        for (var xx = 8.0; xx < w - 8; xx += 24) {
          d.sprite(
            side == 1 ? 'window2' : 'window1',
            x + xx,
            y + yy,
            frame: n.abs() % 3,
            w: 16,
            h: 16,
          );
          final lit =
              ((n * 31 + yy.toInt() * 7 + xx.toInt() * 13) % 11 == 0) &&
              (s.t * 0.5 + n + yy).floor() % 7 != 0;
          if (lit) {
            d.alpha = 0.55;
            d.rect(x + xx + 5, y + yy + 5, 6, 7, const Color(0xFFF2E2A0));
            d.alpha = 1;
          }
        }
      }
      for (var xx = 0.0; xx < w; xx += 16) {
        d.sprite('roof1', x + xx, y, frame: 1, w: 16, h: 16);
      }
      // Edge shading toward the playfield so façades feel solid.
      d.gradientRect(
        left ? x + w - 14 : x,
        y,
        14,
        period,
        left ? const Color(0x00000000) : const Color(0x55000000),
        left ? const Color(0x55000000) : const Color(0x00000000),
        vertical: false,
      );
      d.sprite('ac', left ? x + 47 : x + 2, y + 112, scale: 0.75);
      if (n % 2 == 0) {
        d.sprite('escape', left ? x + 51 : x - 5, y + 24, scale: 0.5);
      }
      // Pipework running down the inner edge.
      final px = left ? x + w - 6 : x + 3;
      d.rect(px, y, 3, period, const Color(0xFF2A2A31));
      d.rect(px + 1, y, 1, period, const Color(0xFF6E6E7C));
      for (var yy = 40.0; yy < period; yy += 96) {
        d.rect(px - 1, y + yy, 5, 4, const Color(0xFF53535E));
      }
    }
  }
  // Altitude plaques every 100 m on the left façade, in world space.
  final topHeight = ((448 - cy) / 300).ceil() * 100;
  for (
    var alt = math.max(100, topHeight - 500);
    alt <= topHeight + 100;
    alt += 100
  ) {
    final y = 448 - alt * 3 - cy;
    if (y < -20 || y > h + 20) continue;
    d.rect(0, y - 1, 30, 1, const Color(0xFFF1F1F5));
    d.rect(0, y, 30, 12, const Color(0xFF1F1F26));
    d.rect(1, y + 1, 28, 10, const Color(0xFFE3C15A));
    d.label('$alt', 15, y + 9, const Color(0xFF2A2A31), size: 8);
    d.rect(30, y + 5, 6, 2, const Color(0xFF1F1F26));
  }
  // Airborne dust uses low contrast so it cannot be confused with trajectory dots.
  d.alpha = 0.2;
  for (var i = 0; i < 18; i++) {
    final x = (i * 71 + s.t * 8) % 360;
    final y = (((i * 53 - cy * 0.12 + s.t * 3) % h) + h) % h;
    d.rect(x, y, 1, 1, const Color(0xFFFFFFFF));
  }
  d.alpha = 1;
}

double _tanh(double x) {
  final e2 = math.exp(2 * x);
  return (e2 - 1) / (e2 + 1);
}
