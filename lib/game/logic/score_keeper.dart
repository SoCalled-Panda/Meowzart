import '../../core/constants.dart';
import 'judge.dart';

/// Pure score + combo state. The game feeds judgements in; nothing here knows
/// about Flame, audio, or time.
class ScoreKeeper {
  int score = 0;
  int combo = 0;
  int maxCombo = 0;
  int perfects = 0;
  int goods = 0;
  int misses = 0;

  /// 1..4, derived from [combo]. The note that *reaches* a threshold scores at
  /// the new multiplier (combo is incremented before this is read).
  int get multiplier {
    var m = 1;
    for (var i = 0; i < kMultiplierThresholds.length; i++) {
      if (combo >= kMultiplierThresholds[i]) m = i + 1;
    }
    return m;
  }

  int get totalNotes => perfects + goods + misses;

  /// Perfect + Good over total notes. 0 until the first note resolves.
  double get accuracy => totalNotes == 0 ? 0 : (perfects + goods) / totalNotes;

  /// Returns the combo milestone to celebrate, or `null`.
  int? apply(Judgement judgement) {
    switch (judgement) {
      case Judgement.perfect:
        perfects++;
        combo++;
        score += kPerfectScore * multiplier;
      case Judgement.good:
        goods++;
        combo++;
        score += kGoodScore * multiplier;
      case Judgement.miss:
        misses++;
        combo = 0;
        score += kMissScore;
    }
    if (combo > maxCombo) maxCombo = combo;
    return kComboMilestones.contains(combo) ? combo : null;
  }

  void reset() {
    score = 0;
    combo = 0;
    maxCombo = 0;
    perfects = 0;
    goods = 0;
    misses = 0;
  }
}
