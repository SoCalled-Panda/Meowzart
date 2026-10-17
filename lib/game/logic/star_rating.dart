import '../../core/constants.dart';

/// | Stars | Requirement |
/// |-------|-------------|
/// | 1 | Finished the song |
/// | 2 | accuracy >= 70% |
/// | 3 | accuracy >= 90% AND no naps |
///
/// Any nap therefore caps the result at 2 stars.
abstract final class StarRating {
  static int compute({required double accuracy, required int napCount}) {
    if (accuracy >= kStarThreeStarAccuracy && napCount == 0) return 3;
    if (accuracy >= kStarTwoStarAccuracy) return 2;
    return 1;
  }
}
