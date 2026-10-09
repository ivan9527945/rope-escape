import 'dart:math' as math;

import 'types.dart';

// Deterministic particle emitter driven by the simulation seed, so prediction
// clones and the live state never diverge.
const _max = 160;

double _noise(ClimbState s) {
  s.shakeSeed = (s.shakeSeed * 1664525 + 1013904223) & 0xFFFFFFFF;
  return ((s.shakeSeed >>> 8) & 0xffff) / 0x10000;
}

void _emit(
  ClimbState s,
  int count,
  Particle Function(double Function() u) make,
) {
  for (var i = 0; i < count && s.particles.length < _max; i++) {
    s.particles.add(make(() => _noise(s)));
  }
}

void stepParticles(ClimbState s, double dt) {
  final a = s.particles;
  if (a.isEmpty) return;
  for (var i = a.length - 1; i >= 0; i--) {
    final p = a[i];
    p.life -= dt;
    if (p.life <= 0) {
      a[i] = a[a.length - 1];
      a.removeLast();
      continue;
    }
    p.vy += p.gravity * dt;
    p.vx *= math.exp(-dt * (p.kind == ParticleKind.dust ? 2.5 : 0.8));
    p.x += p.vx * dt;
    p.y += p.vy * dt;
  }
}

void burstCatch(ClimbState s, double x, double y) {
  _emit(s, 14, (u) {
    final a = u() * math.pi * 2, v = 40 + u() * 90;
    return Particle(
      kind: ParticleKind.spark,
      x: x,
      y: y,
      vx: math.cos(a) * v,
      vy: math.sin(a) * v - 30,
      max: 0.25 + u() * 0.25,
      size: u() < 0.3 ? 2 : 1,
      color: u() < 0.6 ? 0xFFF4F0C2 : 0xFFCCE493,
      gravity: 160,
    );
  });
  _emit(
    s,
    1,
    (u) => Particle(
      kind: ParticleKind.ring,
      x: x,
      y: y,
      vx: 0,
      vy: 0,
      max: 0.3,
      size: 6,
      color: 0xFFDCE7CE,
      gravity: 0,
    ),
  );
}

void puffJump(ClimbState s, double x, double y, double dir) {
  _emit(
    s,
    8,
    (u) => Particle(
      kind: ParticleKind.dust,
      x: x + (u() - 0.5) * 8,
      y: y + (u() - 0.5) * 8,
      vx: -dir * (20 + u() * 50) + (u() - 0.5) * 30,
      vy: 10 + u() * 30,
      max: 0.3 + u() * 0.3,
      size: 1 + u().round().toDouble(),
      color: 0xFFE8E8EE,
      gravity: -20,
    ),
  );
}

void sparksMetal(ClimbState s, double x, double y) {
  _emit(s, 22, (u) {
    final a = -math.pi * 0.9 + u() * math.pi * 0.8, v = 90 + u() * 160;
    return Particle(
      kind: ParticleKind.spark,
      x: x,
      y: y,
      vx: math.cos(a) * v,
      vy: math.sin(a) * v,
      max: 0.3 + u() * 0.4,
      size: 1,
      color: u() < 0.5 ? 0xFFFFD27A : 0xFFFF8A5B,
      gravity: 380,
    );
  });
}

void fibersSnap(ClimbState s, double x, double y) {
  _emit(
    s,
    12,
    (u) => Particle(
      kind: ParticleKind.fiber,
      x: x + (u() - 0.5) * 4,
      y: y + (u() - 0.5) * 20,
      vx: (u() - 0.5) * 90,
      vy: -20 + u() * 60,
      max: 0.6 + u() * 0.5,
      size: 1,
      color: u() < 0.5 ? 0xFF71523B : 0xFFA73D3B,
      gravity: 200,
    ),
  );
}

void debrisDeath(ClimbState s, double x, double y) {
  const colors = [0xFF35353D, 0xFFB94B4C, 0xFFEDEDF0, 0xFF777786];
  _emit(s, 26, (u) {
    final a = u() * math.pi * 2, v = 60 + u() * 150;
    return Particle(
      kind: ParticleKind.debris,
      x: x,
      y: y,
      vx: math.cos(a) * v,
      vy: math.sin(a) * v - 80,
      max: 0.7 + u() * 0.5,
      size: 1 + (u() * 2).round().toDouble(),
      color: colors[(u() * 4).floor().clamp(0, 3)],
      gravity: 320,
    );
  });
}

void glowPickup(ClimbState s, double x, double y, int color) {
  _emit(s, 10, (u) {
    final a = u() * math.pi * 2;
    return Particle(
      kind: ParticleKind.glow,
      x: x + math.cos(a) * 6,
      y: y + math.sin(a) * 6,
      vx: math.cos(a) * 25,
      vy: math.sin(a) * 25 - 40,
      max: 0.5 + u() * 0.3,
      size: 2,
      color: color,
      gravity: -30,
    );
  });
}

void trailStreak(ClimbState s, double x, double y, double vx, double vy) {
  _emit(
    s,
    1,
    (u) => Particle(
      kind: ParticleKind.dust,
      x: x + (u() - 0.5) * 10,
      y: y + (u() - 0.5) * 10,
      vx: -vx * 0.08,
      vy: -vy * 0.08,
      max: 0.18 + u() * 0.1,
      size: 1,
      color: 0xFFF4F4F8,
      gravity: 0,
    ),
  );
}
