import 'package:flutter_test/flutter_test.dart';
import 'package:rope_escape/game/controller.dart';
import 'package:rope_escape/game/rope_core.dart';
import 'package:rope_escape/game/types.dart';

import 'rope_core_test.dart' show planRope;

bool _catchAhead(ClimbState s) {
  final f = predictClimb(s);
  return f.result == 'catch' && f.target != null && f.target!.id > s.attached!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('assisted jump waits for a catch to line up, then releases', () {
    // Rebuild the planner's control sequence, then back up to the last frame
    // where a release would still miss, so the assist has to wait.
    final plan = planRope(createClimb())!;
    ClimbState at(int frames) {
      final s = createClimb()..armed = true;
      for (var i = 0; i < plan.lowers; i++) {
        ropeAction(s, RopeAction.lower);
      }
      for (var i = 0; i < plan.pumps; i++) {
        ropeAction(s, RopeAction.pump);
      }
      for (var i = 0; i < frames; i++) {
        stepClimb(s, 1 / 60);
      }
      return s;
    }

    var k = (plan.wait * 60).round();
    while (k > 0 && _catchAhead(at(k))) {
      k--;
    }
    final start = at(k);
    expect(_catchAhead(start), isFalse, reason: 'need a frame that misses');
    final game = GameController();
    game.s = start;
    game.jump();
    expect(game.jumpQueued, isTrue);
    expect(game.s.attached, isNotNull, reason: 'the miss is not released');
    var frames = 0;
    while (game.s.attached != null && frames < 27) {
      game.update(1 / 60);
      frames++;
    }
    expect(game.s.attached, isNull, reason: 'queued jump fires on the catch');
    expect(game.jumpQueued, isFalse);
    game.dispose();
  });

  test('assisted jump gives up with a notice when nothing lines up', () {
    final game = GameController();
    game.s = createClimb(7)..armed = true;
    // Shorten the rope swing so a release goes nowhere: hang still.
    game.s.omega = 0;
    game.s.theta = 0;
    game.jump();
    expect(game.jumpQueued, isTrue);
    expect(game.s.attached, isNotNull);
    for (var i = 0; i < 40; i++) {
      game.update(1 / 60);
    }
    expect(game.jumpQueued, isFalse);
    expect(game.s.notice, contains('NOT YET'));
    game.dispose();
  });

  test('swipe jump releases immediately without assist', () {
    final game = GameController();
    game.s = createClimb(9)..armed = true;
    game.s.omega = 0;
    game.s.theta = 0;
    game.jump(assist: false);
    expect(game.s.attached, isNull);
    game.dispose();
  });
}
