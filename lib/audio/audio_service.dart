import 'dart:math' as math;

import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../core/constants.dart';
import '../data/models/chart.dart';

/// Audio clock + meow/backing playback, per architecture §6.1/§8.
///
/// The song clock is the audio position interpolated between [SoLoud]
/// position callbacks, with the chart's `audio_offset_ms` and the player's
/// `latencyOffsetMs` applied exactly once. The 2 s lead-in lives here:
/// [now] runs from −leadInS while the backing starts at 0.
class SongClock {
  SongClock({this.latencyOffsetMs = 0, this.audioOffsetMs = 0});

  int latencyOffsetMs;
  int audioOffsetMs;

  double _lastAudioPos = 0;
  final Stopwatch _sw = Stopwatch();

  void reset() {
    _lastAudioPos = 0;
    _sw
      ..reset()
      ..start();
  }

  void pause() => _sw.stop();
  void resume() => _sw.start();

  double now(double audioPosS) {
    // The audio thread reports its position in buffer-sized steps, so the
    // wall clock is the fine-grained part of the estimate. Only re-anchor
    // when the two drift apart by more than [kMaxClockDriftS] — snapping on
    // every report would fold the buffer period into the clock.
    final predicted = _lastAudioPos + _sw.elapsedMicroseconds / 1e6;
    if ((audioPosS - predicted).abs() > kMaxClockDriftS) {
      _lastAudioPos = audioPosS;
      _sw
        ..reset()
        ..start();
      return audioPosS + audioOffsetMs / 1000.0 - latencyOffsetMs / 1000.0;
    }
    return predicted + audioOffsetMs / 1000.0 - latencyOffsetMs / 1000.0;
  }
}

/// Owns SoLoud: backing track + pitch-shifted meow hits.
///
/// Ships with a silent-song fallback: if the backing asset is missing or
/// SoLoud fails to init, [available] is false and the game drives the clock
/// from a stopwatch so the chart is still playable (meows muted).
class AudioService {
  AudioService({SoLoud? engine}) : _engine = engine;

  /// One engine for the whole app: [SoLoud] is a singleton, and re-loading the
  /// meow samples for every run would leak [AudioSource]s. Screens share this.
  static final AudioService instance = AudioService();

  /// Keeps ~8 meow voices plus the backing track comfortably inside the mixer.
  static const int _maxVoices = 32;

  /// Meow one-shots, in preference order. `prep_meows.py` writes the WAVs
  /// from the raw recordings; the MP3s are the fallback so a fresh clone with
  /// only the source recordings still plays.
  static const Map<MeowSample, List<String>> _meowAssets = {
    MeowSample.low: [
      'assets/audio/meows/meow_low.wav',
      'assets/audio/meows/low.mp3',
    ],
    MeowSample.lowMid: [
      'assets/audio/meows/meow_lowMid.wav',
      'assets/audio/meows/lowMid.mp3',
    ],
    MeowSample.mid: [
      'assets/audio/meows/meow_mid.wav',
      'assets/audio/meows/mid.mp3',
    ],
    MeowSample.midHigh: [
      'assets/audio/meows/meow_midHigh.wav',
      'assets/audio/meows/midHigh.mp3',
    ],
    MeowSample.high: [
      'assets/audio/meows/meow_high.wav',
      'assets/audio/meows/high.mp3',
    ],
  };

  /// Null until [init] resolves the singleton. Touching [SoLoud.instance]
  /// loads the native library, which must not happen merely by *constructing*
  /// the service — a `flutter test` host has no flutter_soloud_plugin.dll,
  /// and the silent-song fallback has to be reachable from there.
  SoLoud? _engine;

  /// Every use is behind `_ready` or runs inside [init], which assigns
  /// [_engine] first.
  SoLoud get _so => _engine!;

  bool _ready = false;
  bool _songPlaying = false;

  AudioSource? _song;
  SoundHandle? _songHandle;
  final Map<MeowSample, AudioSource> _meows = {};
  double _songLenS = 0;
  double _songVolume = 0.6;
  double _lastGoodPos = 0;

  bool get available => _ready;
  bool get songPlaying => _songPlaying;

  /// Idempotent: the first caller pays for init, everyone else awaits it.
  Future<bool> ensureReady() async {
    if (_ready) return true;
    await init();
    return _ready;
  }

  Future<void> init() async {
    if (_ready) return;
    try {
      _engine ??= SoLoud.instance;
      await _so.init();
      _so.setMaxActiveVoiceCount(_maxVoices);
      for (final entry in _meowAssets.entries) {
        final source = await _loadFirstAvailable(entry.value);
        if (source == null) throw StateError('no meow asset for ${entry.key}');
        _meows[entry.key] = source;
      }
      _ready = true;
    } catch (_) {
      // Silent-song fallback: the chart is still playable, meows are muted.
      _ready = false;
    }
  }

  /// First asset in [candidates] that SoLoud can decode, or null.
  Future<AudioSource?> _loadFirstAvailable(List<String> candidates) async {
    for (final asset in candidates) {
      try {
        return await _so.loadAsset(asset);
      } catch (_) {
        // Missing/undecodable: try the next candidate.
      }
    }
    return null;
  }

  Future<bool> startSong(String asset, {double volume = 0.6}) async {
    stopSong();
    _lastGoodPos = 0;
    if (!_ready) return false;
    try {
      _song = await _so.loadAsset(asset);
      _songLenS = _so.getLength(_song!).inMicroseconds / 1e6;
      _songVolume = volume;
      _songHandle = await _so.play(_song!, volume: volume);
      _songPlaying = true;
      return true;
    } catch (_) {
      _songPlaying = false;
      return false;
    }
  }

  double songLengthS() => _songLenS;

  /// Volume the backing track is currently playing at.
  double get songVolume => _songVolume;

  /// Live volume change for the running backing track (pause-menu slider).
  void setSongVolume(double volume) {
    _songVolume = volume;
    final handle = _songHandle;
    if (!_ready || handle == null) return;
    try {
      _so.setVolume(handle, volume);
    } catch (_) {}
  }

  double positionSeconds() {
    if (!_ready || !_songPlaying || _songHandle == null) return 0;
    try {
      return _so.getPosition(_songHandle!).inMicroseconds / 1e6;
    } catch (_) {
      return _lastGoodPos;
    }
  }

  double pollPosition() {
    final p = positionSeconds();
    if (p > 0) _lastGoodPos = p;
    return _lastGoodPos;
  }

  Future<void> playMeow(MeowSample sample, int shift,
      {double volume = 1}) async {
    if (!_ready) return;
    final src = _meows[sample];
    if (src == null) return;
    try {
      final handle = await _so.play(src, volume: volume);
      // shift is clamped to ±5 semitones by the chart validator.
      _so.setRelativePlaySpeed(handle, math.pow(2, shift / 12).toDouble());
    } catch (_) {
      // A dropped meow must never break the run.
    }
  }

  void setPaused(bool paused) {
    if (!_ready || _songHandle == null) return;
    try {
      _so.setPause(_songHandle!, paused);
    } catch (_) {}
  }

  void stopSong() {
    if (_songHandle != null && _ready) {
      try {
        unawaited(_so.stop(_songHandle!));
      } catch (_) {}
    }
    _songHandle = null;
    _songPlaying = false;
    _lastGoodPos = 0;
    if (_song != null && _ready) {
      final source = _song!;
      _song = null;
      try {
        unawaited(_so.disposeSource(source));
      } catch (_) {}
    }
  }

  /// Tears down the current song but deliberately leaves the engine (and the
  /// meow cache) alive: [SoLoud.instance] is process-wide, so tearing it down
  /// here would silence every later run.
  Future<void> dispose() async => stopSong();

  /// Full teardown. Only for tests / app shutdown.
  Future<void> shutdown() async {
    stopSong();
    final meows = _meows.values.toList();
    _meows.clear();
    if (_ready) {
      for (final source in meows) {
        try {
          await _so.disposeSource(source);
        } catch (_) {}
      }
      try {
        _so.deinit();
      } catch (_) {}
    }
    _ready = false;
  }
}
