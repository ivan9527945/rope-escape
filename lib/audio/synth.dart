import 'dart:math' as math;
import 'dart:typed_data';

// Original procedural score and Foley, rendered offline into 16-bit stereo WAV
// buffers: oscillator voices with exponential pitch ramps and band-passed
// noise hits.
const sampleRate = 32000;

double hz(num midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

class Mix {
  final int frames;
  final Float32List left, right;
  Mix(double seconds)
    : frames = (seconds * sampleRate).ceil(),
      left = Float32List((seconds * sampleRate).ceil()),
      right = Float32List((seconds * sampleRate).ceil());

  // Deterministic noise shared by every hit, from a fixed-seed LCG.
  static final Float32List _noise = () {
    final n = Float32List(sampleRate * 2);
    var seed = 419;
    for (var i = 0; i < n.length; i++) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      n[i] = (seed.toSigned(32)) / 2147483648;
    }
    return n;
  }();

  void voice(
    double freq,
    double duration,
    double volume, {
    String type = 'sine',
    double time = 0,
    double? end,
    double pan = 0,
  }) {
    final f0 = math.max(1.0, freq), f1 = math.max(1.0, end ?? freq);
    final start = (time * sampleRate).round();
    final n = (duration * sampleRate).round();
    final attack = math.max(1, (0.005 * sampleRate).round());
    var phase = 0.0;
    final gl = math.min(1.0, 1 - pan), gr = math.min(1.0, 1 + pan);
    for (var i = 0; i < n; i++) {
      final idx = start + i;
      if (idx >= frames) break;
      final u = i / n;
      final f = f0 * math.pow(f1 / f0, u);
      phase += f / sampleRate;
      final p = phase - phase.floor();
      double v;
      switch (type) {
        case 'square':
          v = p < 0.5 ? 1 : -1;
        case 'sawtooth':
          v = 2 * p - 1;
        case 'triangle':
          v = 4 * (p < 0.5 ? p : 1 - p) - 1;
        default:
          v = math.sin(p * math.pi * 2);
      }
      // Linear attack then exponential decay to -80 dB, like the gain ramps.
      final env = i < attack
          ? i / attack
          : math
                .pow(0.0001 / 1, (i - attack) / math.max(1, n - attack))
                .toDouble();
      final sample = v * volume * env;
      left[idx] += sample * gl;
      right[idx] += sample * gr;
    }
  }

  void noiseHit(
    double duration,
    double volume,
    double freq, {
    double time = 0,
    double pan = 0,
    int offset = 0,
  }) {
    final start = (time * sampleRate).round();
    final n = (duration * sampleRate).round();
    final attack = math.max(1, (0.003 * sampleRate).round());
    // Biquad band-pass (Q 0.7) at the requested centre frequency.
    final w0 = 2 * math.pi * freq / sampleRate;
    final alpha = math.sin(w0) / (2 * 0.7);
    final b0 = alpha, b1 = 0.0, b2 = -alpha;
    final a0 = 1 + alpha, a1 = -2 * math.cos(w0), a2 = 1 - alpha;
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    final gl = math.min(1.0, 1 - pan), gr = math.min(1.0, 1 + pan);
    for (var i = 0; i < n; i++) {
      final idx = start + i;
      if (idx >= frames) break;
      final x0 = _noise[(offset + i) % _noise.length];
      final y0 =
          (b0 / a0) * x0 +
          (b1 / a0) * x1 +
          (b2 / a0) * x2 -
          (a1 / a0) * y1 -
          (a2 / a0) * y2;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
      final env = i < attack
          ? i / attack
          : math.pow(0.0001, (i - attack) / math.max(1, n - attack)).toDouble();
      final sample = y0 * volume * env * 2.2;
      left[idx] += sample * gl;
      right[idx] += sample * gr;
    }
  }

  /// Low-passed looping noise bed for wind ambience.
  void windBed(double cutoff, double volume) {
    final rc = 1 / (2 * math.pi * cutoff);
    final a = (1 / sampleRate) / (rc + 1 / sampleRate);
    var y = 0.0;
    for (var i = 0; i < frames; i++) {
      y += a * (_noise[i % _noise.length] - y);
      left[i] += y * volume * 3;
      right[i] += y * volume * 3;
    }
    // Crossfade the tail into the head so the loop seam is inaudible.
    final fade = math.min(frames ~/ 8, sampleRate ~/ 4);
    for (var i = 0; i < fade; i++) {
      final u = i / fade;
      left[i] = left[i] * u + left[frames - fade + i] * (1 - u);
      right[i] = right[i] * u + right[frames - fade + i] * (1 - u);
    }
  }

  Uint8List toWav({double master = 1}) {
    // Soft limiter keeps mixed hits below full scale, as the compressor did.
    final bytes = ByteData(44 + frames * 4);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    bytes.setUint32(4, 36 + frames * 4, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 2, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 4, Endian.little);
    bytes.setUint16(32, 4, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    str(36, 'data');
    bytes.setUint32(40, frames * 4, Endian.little);
    var o = 44;
    for (var i = 0; i < frames; i++) {
      for (final v in [left[i] * master, right[i] * master]) {
        final limited = v.abs() > 0.8
            ? v.sign * (0.8 + (v.abs() - 0.8) / (1 + (v.abs() - 0.8) * 4))
            : v;
        bytes.setInt16(
          o,
          (limited.clamp(-1.0, 1.0) * 32767).round(),
          Endian.little,
        );
        o += 2;
      }
    }
    return bytes.buffer.asUint8List();
  }
}

/// Renders every gameplay and interface cue into WAV bytes keyed by name.
Map<String, Uint8List> renderEffects() {
  final out = <String, Uint8List>{};
  Mix mix(double seconds) => Mix(seconds);
  void done(String name, Mix m) => out[name] = m.toWav();
  const pan = -0.15;
  {
    final m = mix(0.3);
    m.noiseHit(0.12, 0.075, 950, pan: pan);
    m.voice(155, 0.14, 0.045, type: 'triangle', end: 85, pan: pan);
    m.noiseHit(0.06, 0.035, 2800, time: 0.025, pan: pan, offset: 900);
    done('jump', m);
  }
  {
    final m = mix(0.3);
    m.noiseHit(0.08, 0.11, 2200, pan: pan);
    m.voice(790, 0.055, 0.055, type: 'triangle', end: 450, pan: pan);
    m.voice(165, 0.18, 0.045, time: 0.035, end: 80, pan: pan);
    m.noiseHit(0.16, 0.04, 700, time: 0.025, pan: pan, offset: 1200);
    done('catch', m);
  }
  for (final name in ['pump', 'swing', 'lower']) {
    final m = mix(0.3);
    m.noiseHit(
      name == 'swing' ? 0.21 : 0.13,
      0.045,
      name == 'lower' ? 1700 : 700,
      pan: pan,
    );
    m.voice(name == 'pump' ? 170 : 230, 0.15, 0.016, end: 95, pan: pan);
    done(name, m);
  }
  {
    final m = mix(0.35);
    m.voice(620, 0.13, 0.05);
    m.voice(930, 0.2, 0.04, time: 0.07);
    done('pickup', m);
  }
  {
    final m = mix(0.6);
    m.noiseHit(0.35, 0.16, 430);
    m.voice(125, 0.45, 0.14, end: 30);
    done('death', m);
  }
  {
    final m = mix(0.45);
    m.noiseHit(0.09, 0.14, 3200, pan: pan);
    m.voice(420, 0.08, 0.06, type: 'square', end: 90, pan: pan);
    m.noiseHit(0.3, 0.05, 900, time: 0.04, pan: pan, offset: 500);
    done('snap', m);
  }
  {
    final m = mix(0.35);
    m.noiseHit(0.18, 0.13, 3600, pan: pan);
    m.voice(880, 0.22, 0.05, type: 'triangle', end: 660, pan: pan);
    m.voice(220, 0.2, 0.06, end: 110, pan: pan);
    done('block', m);
  }
  {
    final m = mix(0.2);
    m.noiseHit(0.12, 0.07, 4200, pan: pan);
    m.voice(1200, 0.1, 0.02, type: 'triangle', end: 700, pan: pan);
    done('graze', m);
  }
  {
    final m = mix(0.6);
    for (final (i, n) in [62, 66, 69, 74].indexed) {
      m.voice(hz(n), 0.22, 0.04, type: 'triangle', time: i * 0.07);
    }
    done('milestone', m);
  }
  // Interface cues.
  {
    final m = mix(0.3);
    m.voice(660, 0.09, 0.05, end: 440);
    m.voice(440, 0.14, 0.04, time: 0.08, end: 330);
    done('ui_pause', m);
  }
  {
    final m = mix(0.3);
    m.voice(440, 0.09, 0.05, end: 660);
    m.voice(660, 0.14, 0.04, time: 0.08, end: 880);
    done('ui_resume', m);
  }
  {
    final m = mix(0.1);
    m.voice(880, 0.06, 0.045, type: 'square');
    done('ui_tick', m);
  }
  {
    final m = mix(0.25);
    m.voice(1320, 0.18, 0.06, type: 'square');
    m.noiseHit(0.08, 0.04, 3000);
    done('ui_go', m);
  }
  {
    final m = mix(1.0);
    for (final (i, n) in [57, 53, 50, 45].indexed) {
      m.voice(hz(n), 0.35, 0.05, type: 'triangle', time: i * 0.16);
    }
    done('ui_over', m);
  }
  {
    final m = mix(0.9);
    for (final (i, n) in [64, 68, 71, 76, 80].indexed) {
      m.voice(hz(n), 0.3, 0.05, type: 'triangle', time: i * 0.09);
    }
    m.noiseHit(0.25, 0.04, 5000, time: 0.4);
    done('ui_record', m);
  }
  {
    final m = mix(0.08);
    m.noiseHit(0.03, 0.04, 2500);
    done('ui_click', m);
  }
  return out;
}

/// 64-step minor ostinato loop at 116 BPM; tension is applied via playback rate.
Uint8List renderMusic() {
  const bpm = 116.0;
  final step = 60 / bpm / 2;
  const steps = 64;
  final m = Mix(step * steps + 1.6);
  const roots = [38, 38, 41, 36];
  const pattern = [0, 7, 12, 3, 0, 10, 7, 15];
  for (var n = 0; n < steps; n++) {
    final t = n * step;
    final root = roots[(n ~/ 16) % 4];
    final s = n % 16;
    if (s % 4 == 0) {
      m.voice(hz(root - 12), 0.32, 0.085, time: t);
      m.voice(115, 0.12, 0.085, time: t, end: 43);
    }
    if (s % 4 == 2) m.noiseHit(0.09, 0.045, 1800, time: t, offset: n * 211);
    if (s % 2 == 0) {
      m.noiseHit(
        0.028,
        0.017,
        6500,
        time: t,
        pan: s % 2 == 1 ? 0.15 : -0.15,
        offset: n * 97,
      );
    }
    m.voice(
      hz(root + pattern[s % 8] + 12),
      0.13,
      0.027,
      type: 'triangle',
      time: t,
      pan: s % 2 == 1 ? 0.18 : -0.18,
    );
    if (s == 0) {
      for (final note in [root, root + 7, root + 15]) {
        m.voice(hz(note), 1.5, 0.017, time: t);
      }
    }
  }
  // Fold the ringing tail back onto the loop head so the seam stays musical.
  final loopFrames = (step * steps * sampleRate).round();
  for (var i = loopFrames; i < m.frames; i++) {
    final j = i - loopFrames;
    if (j >= loopFrames) break;
    m.left[j] += m.left[i];
    m.right[j] += m.right[i];
  }
  final trimmed = Mix(step * steps);
  trimmed.left.setRange(0, trimmed.frames, m.left);
  trimmed.right.setRange(0, trimmed.frames, m.right);
  return trimmed.toWav(master: 0.43 * 0.7);
}

Uint8List renderWind() {
  final m = Mix(3.0);
  m.windBed(600, 0.05);
  return m.toWav(master: 0.7);
}
