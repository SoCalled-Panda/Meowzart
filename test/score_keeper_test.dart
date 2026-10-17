import 'package:flutter_test/flutter_test.dart';
import 'package:meowzart/game/logic/judge.dart';
import 'package:meowzart/game/logic/score_keeper.dart';

void main() {
  group('multiplier thresholds', () {
    test('x1 for 0-9, x2 for 10-24, x3 for 25-49, x4 for 50+', () {
      expect((ScoreKeeper()..combo = 0).multiplier, 1);
      expect((ScoreKeeper()..combo = 9).multiplier, 1);
      expect((ScoreKeeper()..combo = 10).multiplier, 2);
      expect((ScoreKeeper()..combo = 24).multiplier, 2);
      expect((ScoreKeeper()..combo = 25).multiplier, 3);
      expect((ScoreKeeper()..combo = 49).multiplier, 3);
      expect((ScoreKeeper()..combo = 50).multiplier, 4);
    });

    test('the note that reaches a threshold scores at the new multiplier', () {
      final keeper = ScoreKeeper();
      for (var i = 0; i < 10; i++) {
        keeper.apply(Judgement.perfect);
      }
      // 9 notes at x1, the 10th at x2
      expect(keeper.score, 9 * 300 + 300 * 2);
      expect(keeper.combo, 10);
      expect(keeper.multiplier, 2);
    });
  });

  group('combo', () {
    test('resets to 0 on a miss but keeps maxCombo', () {
      final keeper = ScoreKeeper();
      keeper.apply(Judgement.perfect);
      keeper.apply(Judgement.good);
      keeper.apply(Judgement.miss);
      expect(keeper.combo, 0);
      expect(keeper.maxCombo, 2);
      expect(keeper.score, 300 + 100);
      expect(keeper.misses, 1);
    });

    test('returns the milestone only when it is crossed', () {
      final keeper = ScoreKeeper();
      for (var i = 0; i < 9; i++) {
        expect(keeper.apply(Judgement.perfect), isNull);
      }
      expect(keeper.apply(Judgement.perfect), 10);
      expect(keeper.apply(Judgement.perfect), isNull);
    });
  });

  group('accuracy', () {
    test('is 0 before any note resolves', () {
      expect(ScoreKeeper().accuracy, 0);
    });

    test('is perfect + good over total', () {
      final keeper = ScoreKeeper()
        ..apply(Judgement.perfect)
        ..apply(Judgement.good)
        ..apply(Judgement.miss);
      expect(keeper.accuracy, closeTo(2 / 3, 1e-9));
      expect(keeper.totalNotes, 3);
    });

    test('reset clears everything', () {
      final keeper = ScoreKeeper()..apply(Judgement.perfect);
      keeper.reset();
      expect(keeper.score, 0);
      expect(keeper.totalNotes, 0);
      expect(keeper.maxCombo, 0);
    });
  });
}
