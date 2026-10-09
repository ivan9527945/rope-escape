import 'dart:math' as math;
import 'dart:ui';

import '../game/types.dart';
import 'draw.dart';

/// Renderer-only decoration state (scarf chain). Never feeds the simulation.
class Decor {
  final List<Pt> scarf = [];
  void reset() => scarf.clear();
}

class PreviewPair {
  final double t;
  final Prediction flight, swing;
  const PreviewPair(this.t, this.flight, this.swing);
}

void _strokePath(Draw d, List<List<double>> pts, Color color, double width) =>
    d.line(pts, color, width, false);

/// Twisted cord: dark sheath, lighter core and alternating highlight ticks.
void _drawCord(Draw d, Rope r, List<List<double>> pts, bool held, double t) {
  final weak = r.wear < 25, frayed = r.kind == 'frayed';
  final sheath = weak
      ? const Color(0xFF7A2D2C)
      : frayed
      ? const Color(0xFF4A3626)
      : const Color(0xFF232329);
  final core = weak
      ? const Color(0xFFC25A52)
      : frayed
      ? const Color(0xFF8F6A48)
      : const Color(0xFF4E4E5A);
  final tick = weak
      ? const Color(0xFFF0B4AE)
      : frayed
      ? const Color(0xFFC9A47B)
      : const Color(0xFF8E8E9C);
  _strokePath(d, pts, sheath, held ? 2.6 : 2);
  _strokePath(d, pts, core, held ? 1.1 : 0.8);
  const stride = 7.0;
  final flicker = weak && (t * 12).floor() % 3 == 0;
  for (var i = 1; i < pts.length; i++) {
    final ax = pts[i - 1][0],
        ay = pts[i - 1][1],
        bx = pts[i][0],
        by = pts[i][1];
    final len = math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
    if (len < 1) continue;
    final nx = (by - ay) / len, ny = -(bx - ax) / len;
    for (var dd = (i * 3) % stride; dd < len; dd += stride) {
      final u = dd / len;
      final x = ax + (bx - ax) * u, y = ay + (by - ay) * u;
      final side = (dd / stride).floor() % 2 == 1 ? 1 : -1;
      d.rect(
        x + nx * side * 0.6 - 0.5,
        y + ny * side * 0.6 - 0.5,
        1,
        1,
        flicker ? const Color(0xFFFFFFFF) : tick,
      );
    }
    if (frayed && i % 3 == 0) {
      final fx = ax + nx * 3, fy = ay + ny * 3;
      _strokePath(
        d,
        [
          [ax, ay],
          [fx, fy + 2],
        ],
        const Color(0xFFA67C52),
        0.7,
      );
      _strokePath(
        d,
        [
          [ax, ay],
          [ax - nx * 2.5, ay - ny * 2.5 + 1.5],
        ],
        const Color(0xFFA67C52),
        0.7,
      );
    }
    if (weak && i % 2 == 1) {
      d.rect(ax + nx * 1.5, ay + ny * 1.5, 1, 1, const Color(0xFFE0695F));
    }
  }
}

/// Overhead I-beam stub with an eye plate and a shackle the rope is tied to.
void _drawAnchor(Draw d, ClimbState s, Rope r, double y, bool held, double t) {
  final x = r.x;
  final weak = r.wear < 25;
  // Beam: web, top and bottom flanges, rivets, drop shadow.
  d.rect(x - 16, y - 9, 32, 6, const Color(0xFF3F3F4A));
  d.rect(x - 16, y - 10, 32, 2, const Color(0xFFF1F1F5));
  d.rect(x - 16, y - 8, 32, 1, const Color(0xFF6E6E7C));
  d.rect(x - 16, y - 3, 32, 1, const Color(0xFF1F1F26));
  d.rect(x - 15, y - 2, 30, 1, const Color(0x33000000));
  for (final dx in const [-12.0, -5.0, 3.0, 10.0]) {
    d.rect(x + dx, y - 7, 2, 2, const Color(0xFF9D9DAB));
    d.rect(x + dx, y - 6, 2, 1, const Color(0xFF24242B));
  }
  // Eye plate welded under the beam, with the shackle pin through it.
  d.rect(x - 3, y - 3, 6, 4, const Color(0xFF53535E));
  d.rect(x - 2, y - 3, 1, 4, const Color(0xFF8E8E9C));
  d.rect(x - 5, y, 10, 2, const Color(0xFF8E8E9C));
  d.rect(x - 5, y, 10, 1, const Color(0xFFD8D8E2));
  // Shackle bow: a U hanging from the pin; flickers red when the rope is nearly gone.
  final bow = weak
      ? ((t * 8).floor() % 2 == 1
            ? const Color(0xFFFF6B61)
            : const Color(0xFF7A2D2C))
      : held
      ? const Color(0xFFE8E8F0)
      : const Color(0xFFC9C9D4);
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = bow;
  d.c.drawArc(
    Rect.fromCircle(center: Offset(x, y + 1), radius: 3.6),
    0,
    math.pi,
    false,
    paint,
  );
  d.c.drawLine(Offset(x - 3.6, y + 1), Offset(x - 3.6, y - 0.5), paint);
  d.c.drawLine(Offset(x + 3.6, y + 1), Offset(x + 3.6, y - 0.5), paint);
  // Knot where the cord is tied through the bow.
  d.rect(
    x - 2,
    y + 3,
    4,
    3,
    r.kind == 'frayed' ? const Color(0xFF8F6A48) : const Color(0xFF4E4E5A),
  );
  d.rect(
    x - 2,
    y + 3,
    4,
    1,
    r.kind == 'frayed' ? const Color(0xFFC9A47B) : const Color(0xFF8E8E9C),
  );
  d.rect(x - 1, y + 6, 2, 1, const Color(0xFF232329));
}

void drawClimber(Draw d, ClimbState s, PreviewPair? preview, Decor decor) {
  final cy = s.camera.y - d.m, p = s.player;
  for (final q in s.trail) {
    d.alpha = math.max(0, 1 - (s.t - q.t) / 0.55) * 0.2;
    d.rect(q.x, q.y - cy, 1, 1, const Color(0xFF35353D));
  }
  d.alpha = 1;
  if (s.mode == Mode.playing && preview != null) {
    for (final entry in [
      ('swing', preview.swing),
      ('flight', preview.flight),
    ]) {
      final (kind, trace) = entry;
      for (var i = 1; i < trace.points.length; i++) {
        final q = trace.points[i];
        d.alpha =
            (kind == 'swing' ? 0.36 : 0.9) *
            (1 - i / (trace.points.length + 8));
        final danger = trace.result == 'danger' && i > trace.points.length - 4;
        final good = trace.result == 'catch' && i > trace.points.length - 8;
        final sz = kind == 'swing' ? 1.0 : 2.0;
        d.rect(
          q.x - 1,
          q.y - cy - 1,
          sz,
          sz,
          danger
              ? const Color(0xFF9C3336)
              : good
              ? const Color(0xFF29665C)
              : const Color(0xFF35353D),
        );
      }
    }
    d.alpha = 1;
    final target = preview.flight.target;
    if (target != null) {
      d.dashedCircle(
        target.x,
        target.y - cy,
        8,
        const Color(0xFF29665C),
        3,
        3,
        1,
        s.pulse * 1.5,
      );
      d.rect(
        target.x - 0.5,
        target.y - cy - 0.5,
        1,
        1,
        const Color(0xFF29665C),
      );
    }
  }
  for (final r in s.ropes) {
    final y = r.y - cy;
    if (y > d.h + 20 || y + r.len < -70) continue;
    final held = r.id == s.attached;
    final pts =
        r.nodes?.map((q) => [q.x, q.y - cy]).toList() ??
        [
          [r.x, y],
          [r.x, y + r.len],
        ];
    _drawCord(d, r, pts, held, s.t);
    if (!r.snapped) _drawAnchor(d, s, r, y, held, s.t);
    if (!held) {
      final e = pts.last;
      d.rect(
        e[0] - 1.5,
        e[1] - 1,
        3,
        3,
        r.kind == 'frayed' ? const Color(0xFF8F6A48) : const Color(0xFF3A3A44),
      );
    }
  }
  final air = s.attached == null;
  final facing = p.vx < -4 ? -1.0 : 1.0;
  final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy);
  final frame = air
      ? (p.vy < 0 ? 16 + (s.t * 10).floor() % 4 : 20 + (s.t * 10).floor() % 7)
      : 16 + (s.t * 6).floor() % 4;
  final sx = p.x.roundToDouble(), sy = (p.y - cy).roundToDouble();
  if (s.mode != Mode.menu) {
    final scarf = decor.scarf;
    if (scarf.isEmpty) {
      for (var i = 0; i < 5; i++) {
        scarf.add(Pt(p.x, p.y));
      }
    }
    scarf[0].x = p.x - facing * 4;
    scarf[0].y = p.y - 6;
    for (var i = 1; i < scarf.length; i++) {
      final a = scarf[i - 1], b = scarf[i];
      final dx = b.x - a.x, dy = b.y - a.y;
      var dist = math.sqrt(dx * dx + dy * dy);
      if (dist == 0) dist = 1;
      const want = 3.2;
      b.x = a.x + (dx / dist) * want - facing * 0.4 - p.vx * 0.004;
      b.y = a.y + (dy / dist) * want + 0.9 + math.sin(s.t * 9 + i) * 0.35;
    }
    if (s.mode != Mode.dying) {
      final pts = scarf.map((q) => [q.x, q.y - cy]).toList();
      _strokePath(d, pts, const Color(0xFF9C3336), 2.4);
      _strokePath(d, pts.sublist(0, 3), const Color(0xFFC45A56), 1);
    }
  }
  if (air && speed > 230 && s.mode == Mode.playing) {
    d.alpha = math.min(0.5, (speed - 230) / 300);
    final ux = -p.vx / speed, uy = -p.vy / speed;
    for (var i = 0; i < 5; i++) {
      final off = (i - 2) * 5.0;
      final ox = -uy * off, oy = ux * off;
      final len = 8 + (i % 3) * 5;
      _strokePath(
        d,
        [
          [sx + ox + ux * 6, sy + oy + uy * 6],
          [sx + ox + ux * (6 + len), sy + oy + uy * (6 + len)],
        ],
        const Color(0xFFFFFFFF),
        1,
      );
    }
    d.alpha = 1;
  }
  d.c.save();
  d.c.translate(sx, sy);
  d.c.rotate(s.bodyAngle * 0.65);
  d.c.scale(facing, 1);
  d.alpha = 0.9;
  for (final o in const [(-1.0, 0.0), (1.0, 0.0), (0.0, -1.0), (0.0, 1.0)]) {
    d.sprite(
      'player',
      -15 + o.$1,
      -14 + o.$2,
      scale: 1.25,
      frame: frame,
      w: 24,
      h: 24,
      tint: const Color(0xFFF4F4F8),
    );
  }
  d.alpha = 1;
  if (!air) {
    // Arms reach to the grip behind the body so the head and hair stay visible.
    _strokePath(
      d,
      [
        [-3, -2],
        [-4, -7],
        [-1, -10],
      ],
      const Color(0xFF232329),
      3,
    );
    _strokePath(
      d,
      [
        [3, -2],
        [2, -7],
        [0, -10],
      ],
      const Color(0xFF232329),
      3,
    );
  }
  d.sprite('player', -15, -14, scale: 1.25, frame: frame, w: 24, h: 24);
  d.rect(-5, 2, 10, 2, const Color(0xFF6B5A3A));
  d.rect(-1, 1, 3, 4, const Color(0xFFD8D8E2));
  if (!air) {
    d.rect(-2, -12, 4, 3, const Color(0xFFF4F4F8));
    d.rect(-2, -2, 3, 3, const Color(0xFFFFFFFF));
  } else {
    _strokePath(
      d,
      [
        [-3, -3],
        [-9, -7],
      ],
      const Color(0xFF232329),
      2.5,
    );
    _strokePath(
      d,
      [
        [3, -3],
        [9, -8],
      ],
      const Color(0xFF232329),
      2.5,
    );
    d.rect(-11, -9, 3, 3, const Color(0xFFF4F4F8));
    d.rect(8, -10, 3, 3, const Color(0xFFF4F4F8));
  }
  d.c.restore();
  if (s.catchFlash > 0) {
    final age = 1 - s.catchFlash / 0.22;
    d.alpha = 1 - age;
    for (var i = 0; i < 14; i++) {
      final a = i * 2.399, dist = 4 + age * (8 + (i % 4) * 3);
      d.rect(
        p.x + math.cos(a) * dist,
        p.y - cy + math.sin(a) * dist,
        1,
        1,
        i % 3 != 0 ? const Color(0xFFDCE7CE) : const Color(0xFFCCE493),
      );
    }
    d.alpha = 1;
  }
  if (s.combo > 1 && s.catchFlash > 0.08) {
    final size = math.min(18, 11 + s.combo).toDouble();
    d.label(
      '×${s.combo}',
      sx,
      sy - 27,
      s.combo >= 5 ? const Color(0xFFF6E39A) : const Color(0xFFC9E8CF),
      size: size,
      outline: const Color(0xFF1F2A24),
    );
  }
}
