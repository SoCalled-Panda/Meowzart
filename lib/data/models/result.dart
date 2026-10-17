import '../../game/logic/star_rating.dart';

class RunResult {
  const RunResult({
    required this.songId,
    required this.difficulty,
    required this.score,
    required this.maxCombo,
    required this.perfects,
    required this.goods,
    required this.misses,
    required this.naps,
    required this.accuracy,
  });

  final String songId;
  final String difficulty;
  final int score;
  final int maxCombo;
  final int perfects;
  final int goods;
  final int misses;
  final int naps;
  final double accuracy;

  int get stars => StarRating.compute(accuracy: accuracy, napCount: naps);

  int get totalNotes => perfects + goods + misses;
}
