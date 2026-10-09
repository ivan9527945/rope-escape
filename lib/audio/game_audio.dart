import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../game/types.dart';
import 'synth.dart';

Future<Map<String, Uint8List>> _renderAll(int _) async => {
  ...renderEffects(),
  'music': renderMusic(),
  'wind': renderWind(),
};

/// Plays the procedurally rendered cues. Rendering happens once in a background
/// isolate; until it finishes every call is a silent no-op.
class GameAudio {
  final Map<String, String> _paths = {};
  final List<AudioPlayer> _pool = [];
  AudioPlayer? _music, _wind;
  final Map<String, int> counts = {};
  final Map<String, DateTime> _last = {};
  bool ready = false;
  bool enabled = true;
  bool _active = false;
  double _tension = 0;
  int _next = 0;
  bool _disposed = false;

  Future<void> init() async {
    try {
      final dir = Directory(
        '${(await getTemporaryDirectory()).path}/rope-audio',
      );
      await dir.create(recursive: true);
      final rendered = await compute(_renderAll, 0);
      for (final e in rendered.entries) {
        final f = File('${dir.path}/${e.key}.wav');
        await f.writeAsBytes(e.value, flush: true);
        _paths[e.key] = f.path;
      }
      if (_disposed) return;
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        final p = AudioPlayer(playerId: 'fx$i');
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        _pool.add(p);
      }
      final music = AudioPlayer(playerId: 'music'),
          wind = AudioPlayer(playerId: 'wind');
      await music.setReleaseMode(ReleaseMode.loop);
      await wind.setReleaseMode(ReleaseMode.loop);
      await music.setVolume(0);
      await wind.setVolume(0);
      _music = music;
      _wind = wind;
      ready = true;
      _applyState();
    } catch (e) {
      debugPrint('audio init failed: $e');
    }
  }

  void setState({
    required bool enabled,
    required Mode mode,
    required double tension,
  }) {
    this.enabled = enabled;
    _tension = tension.clamp(0.0, 1.0);
    final audible = enabled && (mode == Mode.playing || mode == Mode.dying);
    final changed = audible != _active;
    _active = audible;
    if (!ready) return;
    if (changed) _applyState();
    if (audible) {
      _music?.setPlaybackRate(1 + _tension * 0.28);
      _wind?.setVolume((0.5 + 0.5 * _tension) * 0.6);
    }
  }

  Future<void> _applyState() async {
    final music = _music, wind = _wind;
    if (!ready || _disposed || music == null || wind == null) return;
    if (_active) {
      if (music.state != PlayerState.playing) {
        await music.play(DeviceFileSource(_paths['music']!), volume: 0.7);
        await wind.play(DeviceFileSource(_paths['wind']!), volume: 0.3);
      } else {
        await music.setVolume(0.7);
      }
    } else {
      await music.pause();
      await wind.pause();
    }
  }

  /// Gameplay effect; silent unless the game is audible.
  void effect(String name) {
    if (!ready || !enabled || !_active) return;
    final now = DateTime.now();
    final gap = name == 'swing' ? 220 : 35;
    final last = _last[name];
    if (last != null && now.difference(last).inMilliseconds < gap) return;
    _last[name] = now;
    _play(name);
  }

  /// Interface cue; plays whenever sound is enabled, even while paused.
  void ui(String name) {
    if (!ready || !enabled) return;
    _play('ui_$name');
  }

  void _play(String name) {
    final path = _paths[name];
    if (path == null || _pool.isEmpty) return;
    counts[name] = (counts[name] ?? 0) + 1;
    final p = _pool[_next++ % _pool.length];
    p
        .play(DeviceFileSource(path), mode: PlayerMode.lowLatency)
        .catchError((_) {});
  }

  void reset() {
    _last.clear();
    if (ready) _music?.seek(Duration.zero);
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final p in _pool) {
      await p.dispose();
    }
    await _music?.dispose();
    await _wind?.dispose();
  }
}
