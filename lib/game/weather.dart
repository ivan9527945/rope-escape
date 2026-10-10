import 'dart:math' as math;

/// Time-driven climate schedule. Only wind feeds the rope simulation; the rest
/// is kept so the schedule stays deterministic frame for frame.
class Climate {
  final String id, name;
  final double wind, gust;
  const Climate(this.id, this.name, this.wind, this.gust);
}

const climates = [
  Climate('clear', 'Clear night', 0, 0),
  Climate('rain', 'Drizzle', 10, 6),
  Climate('storm', 'Thunderstorm', 14, 44),
  Climate('fog', 'Fog', 3, 0),
  Climate('snow', 'Snow', 7, 12),
  Climate('gale', 'Gale', 17, 70),
];

Climate climate(String id) =>
    climates.firstWhere((c) => c.id == id, orElse: () => climates[0]);

class Environment {
  final String id, name;
  final double wind, gust;
  final bool warn;
  const Environment(this.id, this.name, this.wind, this.gust, this.warn);
}

Environment weatherAt(String id, double t) {
  final w = climate(id);
  final phase = t % 18;
  final gustEnvelope = phase >= 8 && phase < 12
      ? math.sin(((phase - 8) / 4) * math.pi)
      : 0.0;
  final warning = w.gust >= 40 && phase >= 6 && phase < 8;
  final wind =
      w.wind * (0.65 + math.sin(t * 0.37) * 0.28) + w.gust * gustEnvelope;
  return Environment(id, w.name, wind, gustEnvelope, warning);
}

const _sequences = [
  ['clear', 'rain', 'fog', 'storm', 'snow', 'gale'],
  ['rain', 'fog', 'storm', 'gale', 'snow', 'clear'],
  ['storm', 'gale', 'rain', 'fog', 'snow', 'clear'],
];

double _blend(double a, double b, double t) => a + (b - a) * t;

Environment weatherForRun(double t, [int city = 0]) {
  final sequence = _sequences[city.clamp(0, _sequences.length - 1)];
  final index = t < 20 ? 0 : 1 + ((t - 20) / 24).floor();
  final elapsed = t < 20 ? t : (t - 20) % 24;
  final to = sequence[index % sequence.length];
  final from = index > 0 ? sequence[(index - 1) % sequence.length] : to;
  final mix = index > 0 ? math.min(1.0, elapsed / 5) : 1.0;
  final wa = weatherAt(from, t), wb = weatherAt(to, t);
  return Environment(
    to,
    mix < 1 ? '${wa.name} → ${wb.name}' : wb.name,
    _blend(wa.wind, wb.wind, mix),
    _blend(wa.gust, wb.gust, mix),
    wb.warn || (wa.warn && mix < 0.5),
  );
}
