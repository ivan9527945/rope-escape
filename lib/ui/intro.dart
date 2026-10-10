import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/rope_core.dart';
import '../game/types.dart';
import '../render/climber.dart';
import '../render/draw.dart';
import '../render/painter.dart';
import '../render/scenery.dart';
import '../render/sprites.dart';
import 'theme.dart';

/// Length of the launch animation; a tap skips to the end.
const introDuration = Duration(milliseconds: 2600);

/// Launch animation drawn over the menu right after the native launch screen:
/// the canyon rushes up from below as if falling into the city, the climber
/// swings in on a rope, the title stamps in with a flash, then everything
/// fades to reveal the menu. Colours start from the launch screen's steel so
/// there is no visible cut between the two.
class IntroOverlay extends StatefulWidget {
  final Sprites sprites;
  final bool reducedMotion;
  final VoidCallback onDone;
  const IntroOverlay({
    super.key,
    required this.sprites,
    required this.onDone,
    this.reducedMotion = false,
  });
  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.reducedMotion
        ? const Duration(milliseconds: 800)
        : introDuration,
  );
  final ClimbState _scene = createClimb(3)..mode = Mode.menu;
  final Decor _decor = Decor();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Only the first rope is kept: the intro stages its own single swing.
    _scene.ropes = [_scene.ropes.first];
    _scene.traps = [];
    _scene.pickups = [];
    _c.addStatusListener((st) {
      if (st == AnimationStatus.completed && !_done) {
        _done = true;
        widget.onDone();
      }
    });
    _c.forward();
  }

  void _skip() {
    if (_c.value < 0.86) {
      _c.animateTo(1, duration: const Duration(milliseconds: 260));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (_) => _skip(),
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: IntroPainter(
          t: _c.value,
          scene: _scene,
          decor: _decor,
          sprites: widget.sprites,
          reducedMotion: widget.reducedMotion,
        ),
      ),
    ),
  );
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0, 1);
double _easeOut(double x) => 1 - math.pow(1 - x, 3).toDouble();
double _easeInOut(double x) =>
    x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

/// Overshooting pop used for the title stamp.
double _pop(double x) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  const c = 1.70158 * 1.3;
  return 1 + c * math.pow(x - 1, 3) + (c - 1) * math.pow(x - 1, 2);
}

class IntroPainter extends CustomPainter {
  final double t;
  final ClimbState scene;
  final Decor decor;
  final Sprites sprites;
  final bool reducedMotion;
  IntroPainter({
    required this.t,
    required this.scene,
    required this.decor,
    required this.sprites,
    required this.reducedMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stageH = stageHeightFor(size);
    final f = GamePainter.fit(size, stageH);
    final fade = 1 - _seg(t, 0.88, 1.0);
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(0, 0, 0, fade),
    );
    canvas.drawRect(Offset.zero & size, Paint()..color = Pal.shell);
    canvas.save();
    canvas.translate(f.dx, f.dy);
    canvas.scale(f.scale);
    canvas.clipRect(Rect.fromLTWH(0, 0, stageW, stageH));
    final d = Draw(canvas, sprites, h: stageH);
    final m = d.m;
    if (reducedMotion) {
      _paintCalm(d, m, stageH);
    } else {
      _paintScene(d, m, stageH);
      _paintTitle(d, m, stageH);
    }
    canvas.restore();
    canvas.restore();
  }

  /// Reduced-motion variant: the title simply fades in and out.
  void _paintCalm(Draw d, double m, double stageH) {
    final a = math.min(_seg(t, 0.1, 0.4), 1 - _seg(t, 0.75, 1.0));
    d.alpha = a;
    d.label('ROPE ESCAPE', 180, m + 300, Pal.plate, size: 30);
    d.label('STAY ABOVE THE LINE', 180, m + 340, Pal.hazard, size: 9);
    d.alpha = 1;
  }

  void _paintScene(Draw d, double m, double stageH) {
    // Camera plunges from high above the city down to street level; the
    // parallax layers and façades in drawScenery do the rest.
    final drop = _easeOut(_seg(t, 0.08, 0.72));
    scene.camera.y = -2600 * (1 - drop);
    scene.t = t * introDuration.inMilliseconds / 1000;
    scene.player.x = 180;
    final sceneIn = _seg(t, 0.05, 0.35);
    if (sprites.loaded && sceneIn > 0) {
      drawScenery(d, scene);
      // Dim the fresh scene toward steel so it emerges from the launch colour.
      d.alpha = 1 - sceneIn;
      d.rect(0, 0, 360, stageH, Pal.shell);
      d.alpha = 1;
      _paintClimber(d, m);
    }
    // Speed streaks while still falling fast.
    final streak = (1 - drop) * sceneIn;
    if (streak > 0.02) {
      d.alpha = 0.35 * streak;
      for (var i = 0; i < 14; i++) {
        final x = ((i * 53 + 17) % 360).toDouble();
        final len = 30.0 + (i % 4) * 22;
        final y = ((i * 97 + t * 2600) % (stageH + len)) - len;
        d.rect(x, y, 1, len, const Color(0xFFF4F4F8));
      }
      d.alpha = 1;
    }
  }

  void _paintClimber(Draw d, double m) {
    final enter = _easeOut(_seg(t, 0.3, 0.6));
    if (enter <= 0) return;
    // Pendulum that settles slightly as the camera comes to rest; the swing
    // stays above the title band so the two never overlap.
    final swingT = (t * introDuration.inMilliseconds / 1000) - 0.8;
    final amp = 0.95 * (1 - 0.35 * _seg(t, 0.6, 1.0));
    final theta = amp * math.cos(swingT * 2 * math.pi / 1.7);
    final omega = -amp * math.sin(swingT * 2 * math.pi / 1.7);
    const len = 120.0;
    final ax = 180.0, ay = m - 160 + enter * 190;
    final px = ax + math.sin(theta) * len, py = ay + math.cos(theta) * len;
    // Rope geometry is immutable, so the staged anchor is rebuilt each frame;
    // a straight cord of nodes links it to the climber like a held rope.
    final nodes = [
      for (var i = 0; i <= 14; i++)
        CordNode(
          ax + (px - ax) * i / 14,
          ay + (py - ay) * i / 14,
          ax + (px - ax) * i / 14,
          ay + (py - ay) * i / 14,
        ),
    ];
    scene.ropes = [
      Rope(
        id: 0,
        x: ax,
        baseX: ax,
        y: ay,
        len: len,
        wear: 100,
        kind: 'normal',
        phase: 0,
        nodes: nodes,
        cordLength: len,
        wasHeld: true,
      ),
    ];
    scene.attached = 0;
    scene.theta = theta;
    scene.omega = omega;
    scene.player.x = px;
    scene.player.y = py;
    scene.player.vx = omega * 60;
    scene.player.vy = 0;
    scene.camera.x = 0;
    drawClimber(d, scene, null, decor);
  }

  void _paintTitle(Draw d, double m, double stageH) {
    // Hazard rails sweep in from both sides and frame the title.
    final rail = _easeInOut(_seg(t, 0.0, 0.45));
    final y1 = m + 262.0, y2 = m + 352.0;
    _rail(d, -360 + 360 * rail, y1);
    _rail(d, 360 - 360 * rail, y2);
    // Title stamps in with an overshoot, then a brief flash.
    final stamp = _pop(_seg(t, 0.5, 0.78));
    if (stamp > 0) {
      final size = 30 * stamp;
      d.alpha = math.min(1, stamp * 1.4);
      d.label(
        'ROPE ESCAPE',
        180,
        m + 300,
        Pal.plate,
        size: size,
        outline: Pal.dark,
        outlineWidth: 4,
      );
      d.alpha = 1;
    }
    final sub = _seg(t, 0.72, 0.9);
    if (sub > 0) {
      d.alpha = sub;
      d.label(
        'S T A Y   A B O V E   T H E   L I N E',
        180,
        m + 332,
        Pal.hazard,
        size: 7,
        outline: Pal.dark,
        outlineWidth: 2,
      );
      d.alpha = 1;
    }
    final flash = 1 - _seg(t, 0.62, 0.74);
    if (t > 0.62 && flash > 0) {
      d.alpha = 0.32 * flash;
      d.rect(0, 0, 360, stageH, const Color(0xFFFFFFFF));
      d.alpha = 1;
    }
  }

  void _rail(Draw d, double x, double y) {
    d.rect(x, y, 360, 8, Pal.dark);
    for (var i = -1; i < 24; i++) {
      final sx = x + i * 16.0;
      d.poly([
        [sx, y + 8],
        [sx + 8, y],
        [sx + 16, y],
        [sx + 8, y + 8],
      ], Pal.hazard);
    }
    d.rect(x, y + 8, 360, 1, Pal.steel);
  }

  @override
  bool shouldRepaint(covariant IntroPainter old) => true;
}
