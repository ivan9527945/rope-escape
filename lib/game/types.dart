import 'weather.dart';

enum Mode { menu, playing, paused, dying, over }

enum RopeAction { pump, lower, jump }

class Pt {
  double x, y;
  Pt(this.x, this.y);
  Pt clone() => Pt(x, y);
}

class TrailPoint {
  final double x, y, t;
  const TrailPoint(this.x, this.y, this.t);
}

class CordNode {
  double x, y, px, py;
  CordNode(this.x, this.y, this.px, this.py);
  CordNode clone() => CordNode(x, y, px, py);
}

class Player {
  double x, y, vx, vy;
  Player({this.x = 0, this.y = 0, this.vx = 0, this.vy = 0});
  Player clone() => Player(x: x, y: y, vx: vx, vy: vy);
}

class Rope {
  final int id;
  double x;
  final double baseX;
  final double y;
  final double len;
  double wear;
  final String kind;
  final double phase;
  double vx;
  bool snapped;
  List<CordNode>? nodes;
  double? cordLength;
  bool wasHeld;
  Rope({
    required this.id,
    required this.x,
    required this.baseX,
    required this.y,
    required this.len,
    required this.wear,
    required this.kind,
    required this.phase,
    this.vx = 0,
    this.snapped = false,
    this.nodes,
    this.cordLength,
    this.wasHeld = false,
  });
  Rope clone() => Rope(
    id: id,
    x: x,
    baseX: baseX,
    y: y,
    len: len,
    wear: wear,
    kind: kind,
    phase: phase,
    vx: vx,
    snapped: snapped,
    nodes: nodes?.map((n) => n.clone()).toList(),
    cordLength: cordLength,
    wasHeld: wasHeld,
  );
}

class Trap {
  final int id;
  final String type;
  final double x, y, phase, r;
  double? grazed;
  Trap({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.phase,
    this.r = 13,
    this.grazed,
  });
  Trap clone() =>
      Trap(id: id, type: type, x: x, y: y, phase: phase, r: r, grazed: grazed);
}

/// Resolved trap pose for a given time.
class TrapPose {
  final String type;
  final double x, y, r;
  final bool active, warning;
  const TrapPose(this.type, this.x, this.y, this.r, this.active, this.warning);
}

class Pickup {
  final int id;
  final String type;
  final double x, y;
  bool taken;
  Pickup({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.taken = false,
  });
  Pickup clone() => Pickup(id: id, type: type, x: x, y: y, taken: taken);
}

enum ParticleKind { spark, dust, fiber, debris, ring, glow }

class Particle {
  double x, y, vx, vy, life;
  final double max, size, gravity;
  final int color;
  final ParticleKind kind;
  Particle({
    required this.kind,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.max,
    required this.size,
    required this.color,
    required this.gravity,
  }) : life = max;
}

class RunStats {
  int catches = 0,
      jumps = 0,
      pumps = 0,
      lowers = 0,
      maxCombo = 0,
      pickups = 0,
      blocks = 0,
      snaps = 0;
  double airTime = 0, longestAir = 0;
  int nearMisses = 0, milestones = 0;
  RunStats clone() => RunStats()
    ..catches = catches
    ..jumps = jumps
    ..pumps = pumps
    ..lowers = lowers
    ..maxCombo = maxCombo
    ..pickups = pickups
    ..blocks = blocks
    ..snaps = snaps
    ..airTime = airTime
    ..longestAir = longestAir
    ..nearMisses = nearMisses
    ..milestones = milestones;
}

class ClimbState {
  Mode mode = Mode.playing;
  double t = 0;
  Player player = Player();
  Pt camera = Pt(0, 0);
  int? attached = 0;
  double ropeLength = 98;
  double theta = 0.5;
  double omega = 1.8;
  double catchCooldown = 0;
  int combo = 0;
  double highest = 0;
  int jumps = 0;
  int score = 0;
  int seed;
  int rng;
  List<Trap> traps = [];
  List<Pickup> pickups = [];
  int shield = 0;
  double brake = 0;
  double hitCooldown = 0;
  String notice = '';
  double noticeTime = 0;
  double elastic = 0, elasticV = 0, bodyAngle = 0, bodyOmega = 0;
  List<TrailPoint> trail = [];
  List<Rope> ropes = [];
  int nextRope = 0;
  double deathY = 620;
  double deathSpeed = 18;
  double pressure = 0;
  double deathTime = 0;
  List<String> events = [];
  String reason = '';
  Environment environment = weatherForRun(0);
  double catchFlash = 0;
  RunStats stats = RunStats();
  List<Particle> particles = [];
  double shake = 0;
  int shakeSeed;
  double countdown = 0;
  int milestone = 0;
  double milestoneTime = 0;
  double airStart = 0;
  double pulse = 0;

  /// False until the player's first action; the floor and rope wear wait.
  bool armed = true;

  /// Seconds since the run was armed; drives the floor's pursuit speed.
  double chase = 0;

  ClimbState(this.seed) : rng = seed == 0 ? 1 : seed, shakeSeed = seed | 1;

  Rope? get held => attached == null ? null : ropeById(attached!);
  Rope? ropeById(int id) {
    for (final r in ropes) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Deep copy used by trajectory prediction. Decoration lists are dropped.
  ClimbState clone() {
    final s = ClimbState(seed)
      ..mode = mode
      ..t = t
      ..player = player.clone()
      ..camera = camera.clone()
      ..attached = attached
      ..ropeLength = ropeLength
      ..theta = theta
      ..omega = omega
      ..catchCooldown = catchCooldown
      ..combo = combo
      ..highest = highest
      ..jumps = jumps
      ..score = score
      ..rng = rng
      ..traps = traps.map((q) => q.clone()).toList()
      ..pickups = pickups.map((q) => q.clone()).toList()
      ..shield = shield
      ..brake = brake
      ..hitCooldown = hitCooldown
      ..notice = notice
      ..noticeTime = noticeTime
      ..elastic = elastic
      ..elasticV = elasticV
      ..bodyAngle = bodyAngle
      ..bodyOmega = bodyOmega
      ..trail = []
      ..ropes = ropes.map((r) => r.clone()).toList()
      ..nextRope = nextRope
      ..deathY = deathY
      ..deathSpeed = deathSpeed
      ..pressure = pressure
      ..deathTime = deathTime
      ..events = []
      ..reason = reason
      ..environment = environment
      ..catchFlash = catchFlash
      ..stats = stats.clone()
      ..particles = []
      ..shake = shake
      ..shakeSeed = shakeSeed
      ..countdown = countdown
      ..milestone = milestone
      ..milestoneTime = milestoneTime
      ..airStart = airStart
      ..pulse = pulse
      ..armed = armed
      ..chase = chase;
    return s;
  }
}

class Prediction {
  final List<Pt> points;
  final String result;
  final PredictionTarget? target;
  const Prediction(this.points, this.result, this.target);
  static const empty = Prediction([], 'hidden', null);
}

class PredictionTarget {
  final int id;
  final double x, y;
  const PredictionTarget(this.id, this.x, this.y);
}
