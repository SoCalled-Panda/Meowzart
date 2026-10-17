import '../../core/constants.dart';
import 'judge.dart';

/// Soft failure. There is no game over: at 0 the cat naps, scoring pauses for
/// [kNapDurationS] seconds, then the cat wakes at [kMoodWakeAt].
class MoodMeter {
  MoodMeter({double initial = kMoodStart})
      : value = initial.clamp(0, kMoodMax);

  double value;
  int napCount = 0;
  bool isNapping = false;
  double _napTimer = 0;

  /// True while the cat is asleep: the song keeps playing but score, combo and
  /// mood are frozen.
  bool get scoringPaused => isNapping;

  /// Applies a judgement. Returns `false` and changes nothing while napping.
  bool apply(Judgement judgement) {
    if (isNapping) return false;
    switch (judgement) {
      case Judgement.perfect:
        value += kMoodPerfect;
      case Judgement.good:
        value += kMoodGood;
      case Judgement.miss:
        value += kMoodMiss;
    }
    if (value < 0) value = 0;
    if (value > kMoodMax) value = kMoodMax;
    if (value == 0) _fallAsleep();
    return true;
  }

  /// Drives the nap timer. Call once per frame with the frame delta in seconds.
  void update(double dtS) {
    if (!isNapping) return;
    _napTimer -= dtS;
    if (_napTimer <= 0) {
      isNapping = false;
      _napTimer = 0;
      value = kMoodWakeAt;
    }
  }

  void _fallAsleep() {
    if (isNapping) return;
    isNapping = true;
    _napTimer = kNapDurationS;
    napCount++;
  }

  void reset({double initial = kMoodStart}) {
    value = initial.clamp(0, kMoodMax);
    napCount = 0;
    isNapping = false;
    _napTimer = 0;
  }

  /// 0 = asleep, 1 = fully happy. Drives the mood bar icon.
  double get fraction => value / kMoodMax;
}
