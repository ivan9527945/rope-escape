import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../game/types.dart';
import 'audio_store_io.dart'
    if (dart.library.js_interop) 'audio_store_web.dart';
import 'synth.dart';

Future<Map<String, Uint8List>> _renderAll(int _) async => {
  ...renderEffects(),
  'music': renderMusic(),
  'wind': renderWind(),
};

/// Plays the procedurally rendered cues. Rendering happens once in a background
/// isolate (on the web, where isolates are unavailable, `compute` runs it
/// inline); until it finishes every call is a silent no-op. Storage is
/// platform-specific: temp files on mobile, blob URLs on the web.
class GameAudio {
  final Map<String, Source> _sources = {};
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
      final rendered = await compute(_renderAll, 0);
      _sources.addAll(await storeAudio(rendered));
      if (_disposed) return;
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          // Ambient already mixes with other apps; asking for mixWithOthers
          // explicitly trips an audioplayers assertion in debug builds.
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
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
    // Playback failures are never fatal: swallow them so an unprepared player
    // (e.g. a seek before the source loads) cannot surface as an unhandled error.
    if (changed) _applyState().catchError((_) {});
    if (audible) {
      _music?.setPlaybackRate(1 + _tension * 0.28).catchError((_) {});
      _wind?.setVolume((0.5 + 0.5 * _tension) * 0.6).catchError((_) {});
    }
  }

  Future<void> _applyState() async {
    final music = _music, wind = _wind;
    if (!ready || _disposed || music == null || wind == null) return;
    if (_active) {
      if (music.state != PlayerState.playing) {
        await music.play(_sources['music']!, volume: 0.7);
        await wind.play(_sources['wind']!, volume: 0.3);
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
    final src = _sources[name];
    if (src == null || _pool.isEmpty) return;
    counts[name] = (counts[name] ?? 0) + 1;
    final p = _pool[_next++ % _pool.length];
    p.play(src, mode: PlayerMode.lowLatency).catchError((_) {});
  }

  void reset() {
    _last.clear();
    if (ready) _music?.seek(Duration.zero).catchError((_) {});
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final p in _pool) {
      await p.dispose();
    }
    await _music?.dispose();
    await _wind?.dispose();
  }
}
