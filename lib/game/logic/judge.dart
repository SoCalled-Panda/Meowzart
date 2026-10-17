import '../../core/constants.dart';

enum Judgement { perfect, good, miss }

/// Pure timing judgement. No Flame, no Flutter — unit tested at the boundaries.
abstract final class Judge {
  /// Returns [Judgement.perfect] / [Judgement.good], or `null` when the tap is
  /// too far from the note to count as a hit at all (a stray tap).
  static Judgement? classify({required double tapTimeS, required double noteTimeS}) {
    final dtMs = ((tapTimeS - noteTimeS).abs()) * 1000;
    if (dtMs <= kPerfectMs) return Judgement.perfect;
    if (dtMs <= kGoodMs) return Judgement.good;
    return null;
  }

  /// A note that has passed the Good window without being hit is a Miss.
  static bool isAutoMissed({required double noteTimeS, required double songTimeS}) =>
      noteTimeS + kGoodMs / 1000 < songTimeS;

  /// Which note in the lane a tap should consume: the earliest unhit note
  /// still inside the Good window. Returns `null` for a stray tap.
  static int? pickTargetIndex({
    required List<double> noteTimesS,
    required List<bool> hit,
    required double tapTimeS,
  }) {
    int? best;
    for (var i = 0; i < noteTimesS.length; i++) {
      if (hit[i]) continue;
      final dtMs = ((tapTimeS - noteTimesS[i]).abs()) * 1000;
      if (dtMs > kGoodMs) continue;
      if (best == null || noteTimesS[i] < noteTimesS[best]) best = i;
    }
    return best;
  }
}
