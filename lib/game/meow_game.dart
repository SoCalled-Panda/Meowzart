import 'dart:async';

import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/audio_service.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../data/models/chart.dart';
import '../data/models/result.dart';
import '../game/logic/judge.dart';
import '../game/logic/mood_meter.dart';
import '../game/logic/score_keeper.dart';
import '../ui/screens/pause_menu.dart';
import 'components/lane_components.dart';

/// Flame side of the run: lanes, falling tiles, crew cats, judgement.
class MeowGame extends FlameGame with KeyboardEvents {
  MeowGame({
    required this.chart,
    required this.notes,
    required this.difficulty,
    required this.audio,
    required this.hud,
    required this.onFinish,
  });

  final Chart chart;
  final List<NoteData> notes;
  final Difficulty difficulty;
  final AudioService audio;
  final ValueNotifier<HudState> hud;
  final void Function(RunResult) onFinish;

  final ScoreKeeper score = ScoreKeeper();
  final MoodMeter mood = MoodMeter();
  final SongClock clock = SongClock();

  bool playing = false;
  bool pausedFlag = false;
  bool _done = false;
  double songT = -kLeadInS;
  double _stopwatchT = 0;
  final Stopwatch _wall = Stopwatch();
  int _nextMissCheck = 0;
  double _lastHudPush = -1;

  double musicVolume = 0.6;
  double meowVolume = 1.0;

  late final List<LaneComponent> lanes;

  void applySettings(
      {required double music, required double meow, required int offsetMs}) {
    musicVolume = music;
    meowVolume = meow;
    clock.latencyOffsetMs = offsetMs;
    audio.setSongVolume(music);
  }

  void setPaused(bool paused) {
    if (_done) return;
    pausedFlag = paused;
    if (paused) {
      _wall.stop();
      audio.setPaused(true);
    } else {
      audio.setPaused(false);
      _wall.start();
    }
  }

  void restart() {
    for (final n in notes) {
      n.hit = false;
    }
    score.reset();
    mood.reset();
    for (final cat in children.whereType<CatCrew>()) {
      cat.resetPose();
    }
    songT = -kLeadInS;
    _stopwatchT = 0;
    _nextMissCheck = 0;
    _done = false;
    pausedFlag = false;
    clock.reset();
    _wall
      ..reset()
      ..start();
    unawaited(audio.startSong('assets/audio/${chart.audioPath}'));
  }

  @override
  Future<void> onLoad() async {
    await images.loadAll([
      'cats/crew_box.png',
      'cats/crew_dracula.png',
      'cats/crew_idle.png',
      'cats/crew_tan.png',
      'tiles/tile_0.png',
      'tiles/tile_1.png',
      'tiles/tile_2.png',
      'tiles/tile_3.png',
      'ui/hit_line.png',
    ]);
    final laneW = size.x / kLaneCount;
    final hitY = size.y - 200;
    lanes = [
      for (var i = 0; i < kLaneCount; i++)
        LaneComponent(
          index: i,
          x: i * laneW,
          width: laneW,
          hitY: hitY,
          color: AppColors.laneColors[i],
        ),
    ];
    await addAll(lanes);
    await add(HitLineBar(hitY: hitY));
    await add(CatCrew(hitY: hitY));
    clock.audioOffsetMs = chart.audioOffsetMs;
    clock.reset();
    _wall
      ..reset()
      ..start();
    playing = true;
    await audio.startSong('assets/audio/${chart.audioPath}',
        volume: musicVolume);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!playing || pausedFlag || _done) return;
    mood.update(dt);
    if (audio.songPlaying) {
      songT = clock.now(audio.pollPosition());
    } else {
      // Silent fallback: wall clock (meows muted anyway).
      _stopwatchT += dt;
      songT = _stopwatchT - kLeadInS;
    }
    for (final lane in lanes) {
      lane.songT = songT;
    }
    while (_nextMissCheck < notes.length &&
        Judge.isAutoMissed(
            noteTimeS: notes[_nextMissCheck].t, songTimeS: songT)) {
      final n = notes[_nextMissCheck];
      if (!n.hit) {
        n.hit = true;
        _applyJudgement(Judgement.miss, n, auto: true);
      }
      _nextMissCheck++;
    }
    while (_nextMissCheck < notes.length && notes[_nextMissCheck].hit) {
      _nextMissCheck++;
    }
    if (songT > chart.durationS + 1.0) {
      _finish();
    }
    if (songT - _lastHudPush > 0.05) {
      _lastHudPush = songT;
      _pushHud('');
    }
  }

  /// Earliest unhit note in [lane] inside the Good window, or null.
  void tapLane(int lane) {
    if (!playing || pausedFlag || _done) return;
    NoteData? target;
    for (final n in notes) {
      if (n.hit || n.lane != lane) continue;
      if (((songT - n.t).abs()) * 1000 <= kGoodMs) {
        if (target == null || n.t < target.t) target = n;
      }
    }
    if (target == null) return; // stray tap: silent, no penalty
    target.hit = true;
    final j =
        Judge.classify(tapTimeS: songT, noteTimeS: target.t) ?? Judgement.good;
    _applyJudgement(j, target, auto: false);
  }

  /// Desktop / web smoke-test input: DFJK (and arrows) map to lanes 0-3.
  /// Repeats are filtered by [keysPressed]; touch is the real input on mobile.
  /// Not `const`: [LogicalKeyboardKey] overrides `==`, which const maps reject.
  static final Map<LogicalKeyboardKey, int> _keyLanes = {
    LogicalKeyboardKey.keyD: 0,
    LogicalKeyboardKey.keyF: 1,
    LogicalKeyboardKey.keyJ: 2,
    LogicalKeyboardKey.keyK: 3,
    LogicalKeyboardKey.arrowLeft: 0,
    LogicalKeyboardKey.arrowUp: 1,
    LogicalKeyboardKey.arrowDown: 2,
    LogicalKeyboardKey.arrowRight: 3,
  };

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final lane = _keyLanes[event.logicalKey];
    if (lane == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent && keysPressed.contains(event.logicalKey)) {
      tapLane(lane);
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  void _applyJudgement(Judgement j, NoteData note, {required bool auto}) {
    if (mood.scoringPaused) return;
    score.apply(j);
    mood.apply(j);
    if (j != Judgement.miss && !auto) {
      unawaited(audio.playMeow(note.sample, note.shift, volume: meowVolume));
    }
    for (final c in children.whereType<CatCrew>()) {
      c.react(note.lane);
    }
    _pushHud(switch (j) {
      Judgement.perfect => 'Perfect!',
      Judgement.good => 'Good',
      Judgement.miss => 'Miss',
    });
  }

  void _pushHud(String judgement) {
    hud.value = HudState(
      score: score.score,
      combo: score.combo,
      multiplier: score.multiplier,
      mood: mood.value,
      napping: mood.isNapping,
      judgement: judgement,
      songT: songT,
      durationS: chart.durationS,
    );
  }

  void _finish() {
    _done = true;
    playing = false;
    audio.stopSong();
    onFinish(RunResult(
      songId: chart.id,
      difficulty: difficulty.name,
      score: score.score,
      maxCombo: score.maxCombo,
      perfects: score.perfects,
      goods: score.goods,
      misses: score.misses,
      naps: mood.napCount,
      accuracy: score.accuracy,
    ));
  }
}


