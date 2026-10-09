import 'dart:math' as math;

import 'particles.dart';
import 'soft_rope.dart';
import 'types.dart';
import 'weather.dart';

double _clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);

ClimbState createClimb([int seed = 17]) {
  final s = ClimbState(seed);
  s.player.x = 110 + math.sin(s.theta) * 98;
  s.player.y = 350 + math.cos(s.theta) * 98;
  generateRopes(s);
  for (final r in s.ropes) {
    seedCord(
      r,
      r.id == s.attached ? s.player : null,
      r.id == s.attached ? s.ropeLength : r.len,
    );
  }
  return s;
}

double _rand(ClimbState s) {
  var x = s.rng & 0xFFFFFFFF;
  x ^= (x << 13) & 0xFFFFFFFF;
  x ^= x >>> 17;
  x ^= (x << 5) & 0xFFFFFFFF;
  s.rng = x & 0xFFFFFFFF;
  return s.rng / 4294967296;
}

void generateRopes(ClimbState s) {
  while (s.ropes.isEmpty || s.ropes.last.y > s.camera.y - 420) {
    final id = s.nextRope++;
    final prev = s.ropes.isEmpty ? null : s.ropes.last;
    final side = prev != null ? prev.x < 180 : id % 2 == 1;
    final x = id == 0
        ? 110.0
        : (side ? 239 + _rand(s) * 27 : 94 + _rand(s) * 27);
    final y = id == 0
        ? 350.0
        : prev!.y -
              (id < 3
                  ? 98 + _rand(s) * 12
                  : 116 + _rand(s) * 20 + math.min(10, id * 0.3));
    final len = id == 0 ? 120.0 : 88 + _rand(s) * 19;
    final kind = id < 3
        ? 'normal'
        : const [
            'normal',
            'normal',
            'frayed',
            'moving',
            'normal',
          ][(_rand(s) * 5).floor()];
    s.ropes.add(
      Rope(
        id: id,
        x: x,
        baseX: x,
        y: y,
        len: len,
        wear: kind == 'frayed' ? 65 : 100,
        kind: kind,
        phase: _rand(s) * 6.28,
      ),
    );
    // Traps live on the outer walls, leaving an uninterrupted middle route.
    if (id > 2 && id % 3 == 0) {
      s.traps.add(
        Trap(
          id: id,
          type: id % 2 == 1 ? 'saw' : 'fan',
          x: side ? 32 : 328,
          y: y + 40,
          phase: _rand(s) * 6.28,
        ),
      );
    }
    if (id > 1 && id % 4 == 0) {
      s.pickups.add(
        Pickup(id: id, type: id % 8 == 0 ? 'brake' : 'shield', x: x, y: y + 55),
      );
    }
  }
  s.ropes.removeWhere((r) => !(r.y < s.deathY + 120 || r.id == s.attached));
  s.traps.removeWhere((r) => !(r.y < s.deathY + 120));
  s.pickups.removeWhere((r) => !(r.y < s.deathY + 120 && !r.taken));
}

void _failClimb(ClimbState s, String reason) {
  s.mode = Mode.dying;
  s.reason = reason;
  s.attached = null;
  s.player.vy = -65;
  s.shake = math.max(s.shake, 1);
  debrisDeath(s, s.player.x, s.player.y);
  s.events.add('death');
}

TrapPose trapState(Trap q, double t) {
  final phase = (((t + q.phase) % 4.5) + 4.5) % 4.5;
  return TrapPose(
    q.type,
    q.type == 'saw' ? q.x + math.sin(t * 1.6 + q.phase) * 18 : q.x,
    q.y,
    q.r,
    phase > 1.5 && phase < 3.4,
    phase > 0.7 && phase <= 1.5,
  );
}

void ropeAction(ClimbState s, RopeAction action) {
  if (s.mode != Mode.playing || s.attached == null || s.countdown > 0) return;
  final r = s.held;
  if (r == null) return;
  s.armed = true;
  switch (action) {
    case RopeAction.pump:
      s.omega = _clamp(
        s.omega + (s.omega == 0 ? 1 : s.omega.sign) * 1.05,
        -6.2,
        6.2,
      );
      r.wear -= 11;
      s.stats.pumps++;
      s.events.add('pump');
    case RopeAction.lower:
      s.ropeLength = _clamp(s.ropeLength + 12, 25, r.len);
      s.stats.lowers++;
      s.events.add('lower');
    case RopeAction.jump:
      s.player.vx = _clamp(
        math.cos(s.theta) * s.omega * (s.ropeLength + s.elastic) +
            math.sin(s.theta) * s.elasticV +
            r.vx,
        -430,
        430,
      );
      s.player.vy = _clamp(
        -math.sin(s.theta) * s.omega * (s.ropeLength + s.elastic) +
            math.cos(s.theta) * s.elasticV -
            40,
        -430,
        430,
      );
      s.attached = null;
      s.catchCooldown = 0.24;
      s.combo++;
      s.jumps++;
      s.stats.jumps++;
      s.stats.maxCombo = math.max(s.stats.maxCombo, s.combo);
      s.airStart = s.t;
      puffJump(
        s,
        s.player.x,
        s.player.y,
        s.player.vx == 0 ? 1 : s.player.vx.sign,
      );
      s.events.add('jump');
  }
}

void stepClimb(ClimbState s, double dt) {
  if (s.mode == Mode.menu || s.mode == Mode.paused || s.mode == Mode.over) {
    return;
  }
  if (s.countdown > 0) {
    // Resume grace: the world is frozen, only the countdown and screen shake decay.
    s.countdown = s.countdown - dt < 1e-6 ? 0 : s.countdown - dt;
    s.shake = math.max(0, s.shake - dt * 3);
    return;
  }
  s.t += dt;
  s.shake = math.max(0, s.shake - dt * 3);
  s.pulse += dt;
  stepParticles(s, dt);
  if (s.mode == Mode.dying) {
    s.deathTime += dt;
    s.player.vy += 220 * dt;
    s.player.y += s.player.vy * dt;
    if (s.deathTime > 0.8) s.mode = Mode.over;
    return;
  }
  s.milestoneTime = math.max(0, s.milestoneTime - dt);
  s.environment = weatherForRun(s.t);
  final p = s.player;
  s.catchFlash = math.max(0, s.catchFlash - dt);
  s.noticeTime = math.max(0, s.noticeTime - dt);
  s.hitCooldown = math.max(0, s.hitCooldown - dt);
  s.brake = math.max(0, s.brake - dt);
  for (final r in s.ropes) {
    if (r.kind == 'moving') {
      r.x = r.baseX + math.sin(s.t * 1.3 + r.phase) * 13;
      r.vx = math.cos(s.t * 1.3 + r.phase) * 16.9;
    }
  }
  s.catchCooldown = math.max(0, s.catchCooldown - dt);
  if (s.attached != null) {
    final r = s.held;
    if (r != null) {
      s.elasticV +=
          ((s.ropeLength * s.omega * s.omega + 360 * math.cos(s.theta)) *
                  0.055 -
              s.elastic * 55 -
              s.elasticV * 10) *
          dt;
      s.elastic = _clamp(s.elastic + s.elasticV * dt, -2, 10);
      final effectiveLength = s.ropeLength + s.elastic;
      s.omega +=
          ((-360 / s.ropeLength) * math.sin(s.theta) -
              s.omega * 0.09 +
              s.environment.wind * 0.0018) *
          dt;
      s.omega = _clamp(s.omega, -6.2, 6.2);
      s.theta += s.omega * dt;
      p.x = r.x + math.sin(s.theta) * effectiveLength;
      p.y = r.y + math.cos(s.theta) * effectiveLength;
      p.vx =
          math.cos(s.theta) * s.omega * (s.ropeLength + s.elastic) +
          math.sin(s.theta) * s.elasticV +
          r.vx;
      p.vy =
          -math.sin(s.theta) * s.omega * effectiveLength +
          math.cos(s.theta) * s.elasticV;
      if (s.armed) r.wear -= dt * (r.kind == 'frayed' ? 12 : 5.5);
      if (r.wear <= 0) {
        ropeAction(s, RopeAction.jump);
        r.snapped = true;
        s.stats.snaps++;
        s.shake = math.max(s.shake, 0.35);
        fibersSnap(s, p.x, p.y - 12);
        s.notice = 'ROPE SNAPPED!';
        s.noticeTime = 1.4;
        s.events.add('snap');
      }
    } else {
      s.attached = null;
    }
  } else {
    s.stats.airTime += dt;
    if (math.sqrt(p.vx * p.vx + p.vy * p.vy) > 240 &&
        (s.t * 60).floor() % 2 == 0) {
      trailStreak(s, p.x, p.y, p.vx, p.vy);
    }
    p.vy += 205 * dt;
    p.vx += s.environment.wind * 0.35 * dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.vx *= math.exp(-dt * 0.12);
    if (p.x < 12 || p.x > 348) {
      p.vx *= -0.75;
      p.x = _clamp(p.x, 12, 348);
    }
    if (s.catchCooldown <= 0) {
      Rope? hit;
      for (final r in s.ropes) {
        if (r.wear > 0 && cordCatch(r, p) != null) {
          hit = r;
          break;
        }
      }
      if (hit != null) {
        final r = hit;
        s.attached = r.id;
        s.elastic = 0;
        s.elasticV = 0;
        s.ropeLength = _clamp(
          math.sqrt((p.x - r.x) * (p.x - r.x) + (p.y - r.y) * (p.y - r.y)),
          30,
          r.len,
        );
        s.theta = math.atan2(p.x - r.x, p.y - r.y);
        s.omega = _clamp(
          ((p.vx - r.vx) * math.cos(s.theta) - p.vy * math.sin(s.theta)) /
              s.ropeLength,
          -5.5,
          5.5,
        );
        s.catchFlash = 0.22;
        s.stats.catches++;
        s.stats.longestAir = math.max(s.stats.longestAir, s.t - s.airStart);
        s.shake = math.max(s.shake, 0.18);
        burstCatch(s, p.x, p.y);
        s.events.add('catch');
      }
    }
  }
  for (final r in s.ropes) {
    if (r.y + r.len > s.camera.y - 150 && r.y < s.deathY + 100) {
      stepCord(r, s, dt);
    }
  }
  final pose = s.attached != null
      ? -s.theta * 0.65
      : _clamp(p.vx * 0.004, -1.2, 1.2);
  s.bodyOmega +=
      (math.atan2(math.sin(pose - s.bodyAngle), math.cos(pose - s.bodyAngle)) *
              40 -
          s.bodyOmega * 8) *
      dt;
  s.bodyAngle += s.bodyOmega * dt;
  s.trail.add(TrailPoint(p.x, p.y, s.t));
  s.trail.removeWhere((q) => s.t - q.t >= 0.55);
  for (final q in s.pickups) {
    if (!q.taken &&
        math.sqrt((p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y)) < 23) {
      q.taken = true;
      s.stats.pickups++;
      if (q.type == 'shield') {
        s.shield = 1;
        s.notice = 'SHIELD UP · blocks one saw hit';
      } else {
        s.brake = 5;
        s.notice = 'PLATFORM BRAKE · 5 s of breathing room';
      }
      glowPickup(s, q.x, q.y, q.type == 'shield' ? 0xFF9FE0CF : 0xFFF0DC9A);
      s.noticeTime = 2.5;
      s.events.add('pickup');
    }
  }
  for (final raw in s.traps) {
    final q = trapState(raw, s.t);
    if (q.type == 'fan' &&
        q.active &&
        (p.y - q.y).abs() < 45 &&
        (p.x - q.x).abs() < 130) {
      final f = q.x < 180 ? 1 : -1;
      if (s.attached != null) {
        s.omega += f * 2.1 * dt;
      } else {
        p.vx += f * 150 * dt;
      }
    }
    if (q.type == 'saw') {
      final d = math.sqrt(
        (p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y),
      );
      final hit = q.r + 7;
      if (d < hit && s.hitCooldown <= 0) {
        if (s.shield > 0) {
          s.shield = 0;
          s.hitCooldown = 1.4;
          s.stats.blocks++;
          s.shake = math.max(s.shake, 0.5);
          sparksMetal(s, (p.x + q.x) / 2, (p.y + q.y) / 2);
          s.notice = 'SHIELD BLOCKED THE SAW';
          s.noticeTime = 2;
          s.events.add('block');
        } else {
          _failClimb(s, 'Hit a wall saw.');
        }
      } else if (d < hit + 16 &&
          s.attached == null &&
          !(raw.grazed != null && s.t - raw.grazed! < 1.2)) {
        // Grazing past a saw while airborne counts as a near miss once per pass.
        raw.grazed = s.t;
        s.stats.nearMisses++;
        sparksMetal(s, q.x, q.y);
        s.notice = 'NEAR MISS!';
        s.noticeTime = 1;
        s.events.add('graze');
      }
    }
  }
  s.highest = math.max(s.highest, (448 - p.y) / 3);
  s.score = s.highest.floor();
  final reached = (s.score / 100).floor();
  if (reached > s.milestone) {
    s.milestone = reached;
    s.milestoneTime = 1.8;
    s.stats.milestones = reached;
    s.events.add('milestone');
  }
  // Continuous time-driven pursuit plus a bounded catch-up speed: no floor
  // teleport. Nothing moves until the player's first action arms the run.
  if (s.armed) {
    s.chase += dt;
    final gap = s.deathY - p.y;
    s.deathSpeed =
        math.min(72, 18 + s.chase * 0.45) +
        math.min(110, math.max(0, gap - 300) * 0.85);
    s.deathY -= s.deathSpeed * dt * (s.brake > 0 ? 0.2 : 1);
  }
  s.pressure = _clamp(1 - (s.deathY - p.y - 8) / 180, 0, 1);
  // Automatic upward scroll advances the world even when the player waits.
  s.camera.y +=
      (math.min(math.min(s.camera.y, p.y - 260), s.deathY - 548) - s.camera.y) *
      math.min(1, dt * 4);
  if (p.y + 8 >= s.deathY) {
    _failClimb(s, 'Caught by the rising death platform.');
  }
  generateRopes(s);
}

/// Predict with the production integrator; never mutates the live state.
Prediction predictClimb(
  ClimbState s, {
  bool release = true,
  double seconds = 1.8,
}) {
  if (s.mode != Mode.playing) return Prediction.empty;
  final q = s.clone();
  final start = q.attached;
  if (release && q.attached != null) ropeAction(q, RopeAction.jump);
  final points = [Pt(q.player.x, q.player.y)];
  var result = 'air';
  PredictionTarget? target;
  final steps = (seconds * 60).ceil();
  for (var i = 0; i < steps; i++) {
    stepClimb(q, 1 / 60);
    if (i % 3 == 2) points.add(Pt(q.player.x, q.player.y));
    if (q.mode != Mode.playing) {
      result = 'danger';
      break;
    }
    if (release && q.attached != null) {
      result = 'catch';
      target = PredictionTarget(q.attached!, q.player.x, q.player.y);
      points.add(Pt(q.player.x, q.player.y));
      break;
    }
    if (!release && q.attached != start) break;
  }
  return Prediction(points, result, target);
}
