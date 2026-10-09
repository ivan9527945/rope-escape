import 'package:flutter_test/flutter_test.dart';
import 'package:rope_escape/game/rope_core.dart';
import 'package:rope_escape/game/types.dart';

/// Search real control sequences until the next rope is caught, like the web
/// planner: lowers × pumps × wait, then a jump integrated with the real stepper.
({ClimbState state, int lowers, int pumps, double wait, int frames})? planRope(
  ClimbState base,
) {
  for (var lowers = 0; lowers < 4; lowers++) {
    for (var pumps = 0; pumps < 5; pumps++) {
      for (var wait = 0.0; wait < 2.0; wait += 1 / 30) {
        final s = base.clone();
        for (var i = 0; i < lowers; i++) {
          ropeAction(s, RopeAction.lower);
        }
        for (var i = 0; i < pumps; i++) {
          ropeAction(s, RopeAction.pump);
        }
        final waitFrames = (wait * 60).round();
        for (var i = 0; i < waitFrames; i++) {
          stepClimb(s, 1 / 60);
        }
        if (s.mode != Mode.playing || s.attached == null) continue;
        final from = s.attached;
        ropeAction(s, RopeAction.jump);
        for (var f = 1; f <= 150; f++) {
          stepClimb(s, 1 / 60);
          if (s.mode != Mode.playing) break;
          if (s.attached != null) {
            if (s.attached! > from!) {
              return (
                state: s,
                lowers: lowers,
                pumps: pumps,
                wait: wait,
                frames: f,
              );
            }
            break;
          }
        }
      }
    }
  }
  return null;
}

void main() {
  test(
    'climbing retains pump, jump momentum, rope length and automatic catches',
    () {
      final s = createClimb();
      final omega = s.omega;
      ropeAction(s, RopeAction.pump);
      expect(s.omega, greaterThan(omega));
      expect(s.ropes[0].wear, 89);
      ropeAction(s, RopeAction.lower);
      expect(s.ropeLength, 110);
      final plan = planRope(s);
      expect(plan, isNotNull);
      expect(plan!.state.attached! > s.attached!, isTrue);
      ropeAction(s, RopeAction.jump);
      expect(s.attached, isNull);
      expect(s.player.vy, lessThan(0));
    },
  );

  test('death floor rises with elapsed time, kills, and freezes on pause', () {
    final s = createClimb();
    final start = s.deathY;
    for (var i = 0; i < 300; i++) {
      stepClimb(s, 1 / 60);
    }
    expect(s.deathY, lessThan(start - 80));
    expect(s.camera.y, lessThan(0));
    s.mode = Mode.paused;
    final y = s.player.y, t = s.t;
    stepClimb(s, 10);
    expect(s.player.y, y);
    expect(s.t, t);
    s.mode = Mode.playing;
    s.attached = null;
    s.player.y = s.deathY;
    stepClimb(s, 1 / 60);
    expect(s.mode, Mode.dying);
    for (var i = 0; i < 60; i++) {
      stepClimb(s, 1 / 60);
    }
    expect(s.mode, Mode.over);
  });

  test('ropes generate above arbitrarily high cameras', () {
    final s = createClimb();
    s.camera.y = -50000;
    generateRopes(s);
    expect(s.ropes.last.y, lessThan(-50420));
  });

  test('real rope actions climb several laps while tracking stats', () {
    var s = createClimb();
    for (var lap = 0; lap < 6; lap++) {
      final plan = planRope(s);
      expect(plan, isNotNull, reason: 'reachable next rope on lap $lap');
      s = plan!.state;
    }
    expect(s.mode, Mode.playing);
    expect(s.score, greaterThan(150));
    expect(s.stats.jumps, 6);
    expect(s.stats.catches, 6);
    expect(s.stats.maxCombo, greaterThanOrEqualTo(1));
    expect(s.stats.longestAir, greaterThan(0));
  });

  test('pursuing floor catches up continuously without teleporting', () {
    final s = createClimb();
    s.attached = null;
    s.player.y = -900;
    s.player.vy = -100;
    final y = s.deathY;
    stepClimb(s, 1 / 60);
    expect(s.deathSpeed, greaterThan(100));
    expect(y - s.deathY, inExclusiveRange(0, 4));
  });

  test(
    'prediction leaves live state untouched and matches the real release',
    () {
      final s = createClimb();
      for (var i = 0; i < 30; i++) {
        stepClimb(s, 1 / 60);
      }
      final before = (
        s.player.x,
        s.player.y,
        s.theta,
        s.omega,
        s.particles.length,
      );
      final p = predictClimb(s);
      expect(p.points.length, greaterThan(5));
      expect((
        s.player.x,
        s.player.y,
        s.theta,
        s.omega,
        s.particles.length,
      ), before);
      ropeAction(s, RopeAction.jump);
      for (var i = 0; i < 3; i++) {
        stepClimb(s, 1 / 60);
      }
      expect((s.player.x - p.points[1].x).abs(), lessThan(0.001));
      expect((s.player.y - p.points[1].y).abs(), lessThan(0.001));
    },
  );

  test(
    'resume countdown freezes the world and ignores actions until it ends',
    () {
      final s = createClimb();
      s.countdown = 1.5;
      ropeAction(s, RopeAction.pump);
      for (var i = 0; i < 30; i++) {
        stepClimb(s, 1 / 60);
      }
      expect(s.countdown, closeTo(1.0, 1e-9));
      expect(s.t, 0);
      expect(s.stats.pumps, 0);
      for (var i = 0; i < 60; i++) {
        stepClimb(s, 1 / 60);
      }
      expect(s.countdown, 0);
      stepClimb(s, 1 / 60);
      expect(s.t, greaterThan(0));
      ropeAction(s, RopeAction.pump);
      expect(s.stats.pumps, 1);
    },
  );

  test('saw grazes count once per pass and never suppress a real hit', () {
    final s = createClimb();
    s.attached = null;
    s.traps = [Trap(id: 9, type: 'saw', x: 200, y: 300, phase: 0)];
    s.player
      ..x = 230
      ..y = 300
      ..vx = 0
      ..vy = 0;
    s.catchCooldown = 10;
    stepClimb(s, 1 / 60);
    expect(s.stats.nearMisses, 1);
    stepClimb(s, 1 / 60);
    expect(s.stats.nearMisses, 1);
    s.player
      ..x = 205
      ..y = 300
      ..vy = 0;
    stepClimb(s, 1 / 60);
    expect(s.mode, Mode.dying);
    expect(s.particles.any((p) => p.kind == ParticleKind.debris), isTrue);
  });

  test('a shield absorbs a saw hit and records a block', () {
    final s = createClimb();
    s.attached = null;
    s.shield = 1;
    s.traps = [Trap(id: 9, type: 'saw', x: 200, y: 300, phase: 0)];
    s.player
      ..x = 200
      ..y = 300
      ..vy = 0;
    s.catchCooldown = 10;
    stepClimb(s, 1 / 60);
    expect(s.mode, Mode.playing);
    expect(s.shield, 0);
    expect(s.stats.blocks, 1);
    expect(s.events, contains('block'));
  });

  test('milestones fire every 100 m', () {
    final s = createClimb();
    s.highest = 250;
    stepClimb(s, 1 / 60);
    expect(s.milestone, 2);
    expect(s.events, contains('milestone'));
  });

  test(
    'an unarmed run keeps the floor and rope wear frozen until the first action',
    () {
      final s = createClimb()..armed = false;
      final floor = s.deathY, wear = s.ropes[0].wear, x = s.player.x;
      for (var i = 0; i < 300; i++) {
        stepClimb(s, 1 / 60);
      }
      expect(s.deathY, floor);
      expect(s.ropes[0].wear, wear);
      expect(s.player.x, isNot(x), reason: 'the climber still swings');
      expect(s.chase, 0);
      ropeAction(s, RopeAction.pump);
      expect(s.armed, isTrue);
      for (var i = 0; i < 60; i++) {
        stepClimb(s, 1 / 60);
      }
      expect(s.deathY, lessThan(floor));
      expect(s.ropes[0].wear, lessThan(wear));
    },
  );
}
