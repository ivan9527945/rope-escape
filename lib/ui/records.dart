import 'package:shared_preferences/shared_preferences.dart';

/// Persistent personal records (best height, run count, best combo, longest run).
class Records {
  int best, runs, bestCombo, total;
  double bestTime;
  Records({
    this.best = 0,
    this.runs = 0,
    this.bestCombo = 0,
    this.bestTime = 0,
    this.total = 0,
  });

  static Future<Records> load() async {
    final p = await SharedPreferences.getInstance();
    return Records(
      best: p.getInt('best') ?? 0,
      runs: p.getInt('runs') ?? 0,
      bestCombo: p.getInt('bestCombo') ?? 0,
      bestTime: p.getDouble('bestTime') ?? 0,
      total: p.getInt('total') ?? 0,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('best', best);
    await p.setInt('runs', runs);
    await p.setInt('bestCombo', bestCombo);
    await p.setDouble('bestTime', bestTime);
    await p.setInt('total', total);
  }
}

String fmtTime(double t) {
  final m = t ~/ 60, s = (t % 60).floor();
  return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
}

String grade(int score) => score >= 1500
    ? 'S'
    : score >= 900
    ? 'A'
    : score >= 500
    ? 'B'
    : score >= 200
    ? 'C'
    : 'D';

const gradeNote = {
  'S': 'Legendary ascent.',
  'A': 'Expert climb. Go again.',
  'B': 'A steady climbing rhythm.',
  'C': 'Swing basics mastered.',
  'D': 'Every jump is practice.',
};
