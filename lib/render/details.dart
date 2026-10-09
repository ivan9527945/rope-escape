import 'dart:math' as math;
import 'dart:ui';

import '../game/rope_core.dart';
import '../game/types.dart';
import 'draw.dart';

double _hash(int a, int b) =>
    (((a * 73856093) ^ (b * 19349663)) & 0x7FFFFFFF) % 1000 / 1000;

/// 32px machine sprite drawn in place; integer pixels preserve the art style.
void _machine(
  Draw d,
  String type,
  int frame,
  bool active,
  double ox,
  double oy,
) {
  void rect(double x, double y, double w, double h, Color color) =>
      d.rect(ox + x, oy + y, w, h, color);
  if (type == 'fan') {
    rect(0, 0, 32, 32, const Color(0xFF1F1F26));
    rect(1, 1, 30, 30, const Color(0xFFDEDEE7));
    rect(2, 2, 28, 28, const Color(0xFF8D8D9C));
    rect(3, 3, 26, 26, const Color(0xFF53535E));
    rect(5, 5, 22, 22, const Color(0xFF24242B));
    if (active) {
      for (var y = -11; y <= 11; y++) {
        for (var x = -11; x <= 11; x++) {
          if (x * x + y * y < 110 && (x + y + frame) % 3 == 0) {
            rect(16.0 + x, 16.0 + y, 1, 1, const Color(0xFF3D3D49));
          }
        }
      }
    }
  } else {
    d.circle(ox + 16, oy + 16, 13, const Color(0xFF4A4A56));
  }
  final blades = type == 'saw' ? 14 : 4;
  for (var i = 0; i < blades; i++) {
    final a = (i * math.pi * 2) / blades + (frame * math.pi) / 16;
    if (type == 'saw') {
      d.poly([
        [ox + 15.5 + math.cos(a) * 13, oy + 15.5 + math.sin(a) * 13],
        [
          ox + 15.5 + math.cos(a + 0.3) * 10,
          oy + 15.5 + math.sin(a + 0.3) * 10,
        ],
        [
          ox + 15.5 + math.cos(a - 0.12) * 10,
          oy + 15.5 + math.sin(a - 0.12) * 10,
        ],
      ], const Color(0xFFEDEDF0));
    } else {
      for (var r = 3.0; r < 12; r += 2) {
        rect(
          15 + math.cos(a) * r - 2,
          15 + math.sin(a) * r - 2,
          4,
          6,
          active ? const Color(0xFFC4C4D2) : const Color(0xFFAAAABC),
        );
      }
    }
  }
  if (type == 'saw') {
    d.circle(ox + 16, oy + 16, 9, const Color(0xFFB0B0BF));
    for (var y = -9; y <= 9; y++) {
      for (var x = -9; x <= 9; x++) {
        if (x * x + y * y < 82 && (x + y + frame) % 5 == 0) {
          rect(16.0 + x, 16.0 + y, 1, 1, const Color(0xFF777786));
        }
      }
    }
    for (var i = 0; i < 4; i++) {
      final a = (i * math.pi) / 2 + (frame * math.pi) / 16;
      for (var r = 4.0; r < 9; r++) {
        rect(
          16 + math.cos(a) * r,
          16 + math.sin(a) * r,
          1,
          1,
          const Color(0xFF8E8E9C),
        );
      }
    }
  }
  if (type == 'fan') {
    for (var y = 6.0; y < 27; y += 5) {
      rect(5, y, 22, 1, const Color(0xFF6B6B7A));
    }
    rect(15, 5, 1, 22, const Color(0xFF6B6B7A));
  }
  rect(12, 12, 8, 8, const Color(0xFF2A2A31));
  rect(13, 13, 6, 6, const Color(0xFF35353D));
  rect(
    14,
    14,
    4,
    4,
    active ? const Color(0xFFFF5A52) : const Color(0xFFEDEDF0),
  );
}

void drawParticles(Draw d, ClimbState s, double cy) {
  for (final p in s.particles) {
    final u = p.life / p.max;
    if (p.kind == ParticleKind.ring) {
      d.alpha = u;
      d.circle(p.x, p.y - cy, p.size + (1 - u) * 16, Color(p.color), stroke: 1);
      continue;
    }
    d.alpha = p.kind == ParticleKind.dust ? u * 0.55 : math.min(1, u * 1.6);
    final sz = p.kind == ParticleKind.dust ? p.size + (1 - u) * 2 : p.size;
    d.rect(p.x, p.y - cy, sz, sz, Color(p.color));
  }
  d.alpha = 1;
}

void drawDetails(Draw d, ClimbState s) {
  final cy = s.camera.y - d.m;
  for (final r in s.ropes) {
    final y = r.y - cy;
    if (y < -140 || y > d.h + 10) continue;
    if (r.kind == 'moving') {
      d.rect(r.baseX - 26, y - 15, 52, 5, const Color(0xFF53535E));
      d.rect(r.baseX - 26, y - 16, 52, 1, const Color(0xFFF1F1F5));
      d.rect(r.baseX - 26, y - 10, 52, 1, const Color(0xFF1F1F26));
      for (var x = -24.0; x < 26; x += 6) {
        d.rect(r.baseX + x, y - 13, 2, 2, const Color(0xFF24242B));
      }
      d.rect(r.baseX - 27, y - 17, 3, 8, const Color(0xFF35353D));
      d.rect(r.baseX + 24, y - 17, 3, 8, const Color(0xFF35353D));
      d.rect(r.x - 6, y - 17, 12, 9, const Color(0xFFB0B0BF));
      d.rect(r.x - 6, y - 17, 12, 1, const Color(0xFFEDEDF0));
      for (final dx in const [-4.0, 3.0]) {
        d.circle(r.x + dx + 0.5, y - 10.5, 2.2, const Color(0xFF2A2A31));
        final a = r.x * 0.6;
        d.rect(
          r.x + dx + math.cos(a),
          y - 11 + math.sin(a),
          1,
          1,
          const Color(0xFFD8D8E2),
        );
      }
    }
    if (r.kind == 'frayed') {
      final tx = r.x + 14 + math.sin(s.t * 2 + r.phase) * 1.5, ty = y + 4;
      d.line(
        [
          [r.x + 8, y - 2],
          [tx, ty],
        ],
        const Color(0xFF53535E),
        1,
      );
      d.rect(tx - 5, ty, 10, 12, const Color(0xFF1F1F26));
      d.rect(tx - 4, ty + 1, 8, 10, const Color(0xFFE3C15A));
      d.label('!', tx, ty + 9, const Color(0xFF5A3A1F), size: 9);
    }
  }
  for (final raw in s.traps) {
    final q = trapState(raw, s.t);
    final y = q.y - cy;
    if (y < -70 || y > d.h + 40) continue;
    final left = q.x < 180;
    final wallX = left ? 20.0 : 340.0;
    final color = q.warning || q.active
        ? const Color(0xFF963C40)
        : const Color(0xFF35353D);
    final ax = math.min(wallX, q.x), aw = (q.x - wallX).abs();
    d.rect(ax, y - 4, aw, 8, const Color(0xFF3F3F4A));
    d.rect(ax, y - 4, aw, 1, const Color(0xFF8E8E9C));
    d.rect(ax, y + 3, aw, 1, const Color(0xFF1F1F26));
    for (var x = 0.0; x < aw; x += 8) {
      d.rect(
        ax + x + ((s.t * 6).floor() % 2) * 4,
        y - 2,
        4,
        4,
        q.type == 'saw' ? const Color(0xFFC9A24A) : const Color(0xFF6B6B7A),
      );
    }
    d.rect(left ? wallX - 4 : wallX, y - 8, 4, 16, const Color(0xFF1F1F26));
    d.rect(left ? wallX - 3 : wallX + 1, y - 7, 2, 14, const Color(0xFF777786));
    if (q.type == 'saw') {
      d.alpha = 0.25;
      d.circle(q.x, y, 15.5, const Color(0xFFEDEDF0));
      d.alpha = 1;
      final spark = (s.t * 20).floor();
      for (var i = 0; i < 4; i++) {
        final h = _hash(spark + i, raw.id);
        if (h > 0.55) continue;
        final sx = q.x + (left ? -1 : 1) * (12 + h * 10),
            sy = y + 8 + h * 12 + i * 2;
        d.rect(
          sx,
          sy,
          1,
          1,
          i % 2 == 1 ? const Color(0xFFFFD27A) : const Color(0xFFFF8A5B),
        );
      }
    }
    _machine(
      d,
      q.type,
      (s.t *
                  (q.type == 'saw'
                      ? 24
                      : q.active
                      ? 30
                      : 8))
              .floor() %
          32,
      q.type == 'saw' || q.active,
      q.x.roundToDouble() - 16,
      y.roundToDouble() - 16,
    );
    if (q.type == 'fan') {
      final lit = q.active || (q.warning && (s.t * 10).floor() % 2 == 0);
      d.rect(q.x - 3, y - 22, 6, 4, const Color(0xFF2A2A31));
      d.rect(
        q.x - 2,
        y - 21,
        4,
        2,
        lit ? const Color(0xFFFF5A52) : const Color(0xFF59596A),
      );
      d.label(
        q.warning
            ? 'GUST SOON'
            : q.active
            ? 'GUST'
            : 'VENT',
        left ? 57 : 303,
        y - 26,
        color,
        size: 7,
      );
      if (q.active || q.warning) {
        for (var i = 0; i < 9; i++) {
          final dist = (s.t * 150 + i * 15) % 115;
          final x = q.x + (left ? 1 : -1) * dist;
          final yy = y - 24 + i * 6 + math.sin(s.t * 8 + i) * 1.5;
          d.alpha = (q.active ? 0.7 : 0.25) * (1 - dist / 125);
          d.line(
            [
              [x, yy],
              [x + (left ? 12 : -12), yy],
            ],
            const Color(0xFFF4F4F8),
            1,
          );
        }
      }
      d.alpha = 1;
    }
  }
  for (final q in s.pickups) {
    if (q.taken) continue;
    final bob = math.sin(s.t * 3 + q.x) * 2;
    final x = q.x.roundToDouble(), y = (q.y - cy + bob).roundToDouble();
    final ink = q.type == 'shield'
        ? const Color(0xFF9FE0CF)
        : const Color(0xFFF0DC9A);
    d.alpha = 0.25 + math.sin(s.t * 4) * 0.1;
    d.circle(x, y, 14 + math.sin(s.t * 4) * 1.5, ink);
    d.alpha = 1;
    d.rect(x - 9, y - 10, 18, 21, const Color(0xFF1F1F26));
    d.rect(x - 8, y - 9, 16, 18, const Color(0xFFE3E3EB));
    d.rect(x - 7, y - 8, 14, 1, const Color(0xFFFFFFFF));
    d.rect(x - 6, y - 7, 12, 14, const Color(0xFF53535E));
    d.rect(x - 8, y + 6, 16, 2, const Color(0xFF35353D));
    if (q.type == 'shield') {
      d.rect(x - 4, y - 5, 8, 6, ink);
      d.rect(x - 3, y + 1, 6, 3, ink);
      d.rect(x - 1, y + 4, 2, 2, ink);
      d.rect(x - 1, y - 3, 2, 5, const Color(0xFF2D5A4E));
    } else {
      d.rect(x - 4, y - 4, 3, 9, ink);
      d.rect(x + 1, y - 4, 3, 9, ink);
    }
    d.label(
      q.type == 'shield' ? 'SHIELD' : 'SLOW',
      x,
      y + 21,
      const Color(0xFF35353D),
      size: 7,
    );
  }
  drawParticles(d, s, cy);
  if (s.shield > 0) {
    final cx = s.player.x.roundToDouble(),
        cyy = (s.player.y - cy).roundToDouble() - 1;
    final r = 20 + math.sin(s.pulse * 5);
    final pts = <List<double>>[];
    for (var i = 0; i <= 6; i++) {
      final a = (i * math.pi) / 3 + s.pulse * 0.8;
      pts.add([cx + math.cos(a) * r, cyy + math.sin(a) * r]);
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF5FB7A0);
    for (var i = 0; i < 6; i++) {
      final a = pts[i], b = pts[i + 1];
      // Dashed hexagon edge: 4 on / 3 off.
      final dx = b[0] - a[0], dy = b[1] - a[1];
      final len = math.sqrt(dx * dx + dy * dy);
      var t = 0.0;
      while (t < len) {
        final t2 = math.min(len, t + 4);
        d.c.drawLine(
          Offset(a[0] + dx * t / len, a[1] + dy * t / len),
          Offset(a[0] + dx * t2 / len, a[1] + dy * t2 / len),
          paint,
        );
        t += 7;
      }
    }
  }
}
