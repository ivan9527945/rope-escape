import 'dart:math' as math;

import 'types.dart';

// Lightweight Verlet cord. Both ends are constrained only while held; after
// release every node except the anchor retains its velocity and recoils freely.
const _n = 14;

void seedCord(Rope r, Player? p, double length) {
  final nodes = <CordNode>[];
  for (var i = 0; i <= _n; i++) {
    final u = i / _n;
    final x = r.x + (p != null ? p.x - r.x : math.sin(r.phase) * 3) * u;
    final y = r.y + (p != null ? p.y - r.y : r.len) * u;
    nodes.add(CordNode(x, y, x, y));
  }
  r.nodes = nodes;
  r.cordLength = length;
  r.wasHeld = p != null;
}

void stepCord(Rope r, ClimbState s, double dt) {
  final held = r.id == s.attached;
  final p = s.player;
  if (r.nodes == null) {
    seedCord(r, held ? p : null, held ? s.ropeLength : r.len);
  }
  if (held && !r.wasHeld) seedCord(r, p, s.ropeLength);
  r.wasHeld = held;
  final a = r.nodes!;
  final last = a.length - 1;
  final target = held ? (s.ropeLength + s.elastic) * 1.075 : r.len;
  final current = r.cordLength ?? target;
  r.cordLength = current + (target - current) * math.min(1, dt * 9);
  final rest = r.cordLength! / last;
  final wind = s.environment.wind;
  for (var i = r.snapped ? 0 : 1; i < a.length; i++) {
    final q = a[i];
    final vx = (q.x - q.px) * 0.986, vy = (q.y - q.py) * 0.986;
    q.px = q.x;
    q.py = q.y;
    q.x +=
        vx +
        (wind * 0.18 + math.sin(s.t * 1.8 + r.phase + i * 0.2) * 3) * dt * dt;
    q.y += vy + 220 * dt * dt;
  }
  void pin() {
    if (!r.snapped) {
      a[0].x = r.x;
      a[0].y = r.y;
    }
    if (held) {
      a[last].x = p.x;
      a[last].y = p.y;
    }
  }

  pin();
  for (var k = 0; k < (held ? 7 : 4); k++) {
    for (var i = 0; i < last; i++) {
      final q = a[i], b = a[i + 1];
      final dx = b.x - q.x, dy = b.y - q.y;
      var d = math.sqrt(dx * dx + dy * dy);
      if (d == 0) d = 0.001;
      final stretch = ((d - rest) / d) * 0.92;
      final wa = i == 0 && !r.snapped ? 0.0 : 1.0;
      final wb = held && i + 1 == last ? 0.0 : 1.0;
      final total = wa + wb;
      if (total == 0) continue;
      q.x += (dx * stretch * wa) / total;
      q.y += (dy * stretch * wa) / total;
      b.x -= (dx * stretch * wb) / total;
      b.y -= (dy * stretch * wb) / total;
    }
    pin();
  }
  // Bound released node velocities after abrupt catch/length changes.
  for (final q in a) {
    final dx = q.x - q.px, dy = q.y - q.py;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > 10) {
      q.px = q.x - (dx / d) * 10;
      q.py = q.y - (dy / d) * 10;
    }
  }
}

class CordHit {
  final double x, y, length, d;
  const CordHit(this.x, this.y, this.length, this.d);
}

CordHit? cordCatch(Rope r, Player p) {
  final a = r.nodes;
  if (a == null) return null;
  var length = 0.0;
  CordHit? best;
  for (var i = 1; i < a.length; i++) {
    final q = a[i - 1], b = a[i];
    final dx = b.x - q.x, dy = b.y - q.y;
    final l = math.sqrt(dx * dx + dy * dy);
    final ll = l * l == 0 ? 1 : l * l;
    final u = (((p.x - q.x) * dx + (p.y - q.y) * dy) / ll).clamp(0.0, 1.0);
    final x = q.x + dx * u, y = q.y + dy * u;
    final d = math.sqrt((x - p.x) * (x - p.x) + (y - p.y) * (y - p.y));
    if (length + l * u > 24 && d < 17 && (best == null || d < best.d)) {
      best = CordHit(x, y, length + l * u, d);
    }
    length += l;
  }
  return best;
}
