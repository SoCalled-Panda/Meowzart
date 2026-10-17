import 'package:flutter_test/flutter_test.dart';
import 'package:meowzart/game/logic/judge.dart';

void main() {
  group('Judge.classify windows', () {
    test('exactly on the beat is perfect', () {
      expect(Judge.classify(tapTimeS: 1.0, noteTimeS: 1.0), Judgement.perfect);
    });

    test('49 ms is perfect, 51 ms is good', () {
      expect(Judge.classify(tapTimeS: 1.049, noteTimeS: 1.0), Judgement.perfect);
      expect(Judge.classify(tapTimeS: 1.051, noteTimeS: 1.0), Judgement.good);
    });

    test('109 ms is good, 111 ms is not a hit', () {
      expect(Judge.classify(tapTimeS: 1.109, noteTimeS: 1.0), Judgement.good);
      expect(Judge.classify(tapTimeS: 1.111, noteTimeS: 1.0), isNull);
    });

    test('late taps are judged the same as early taps', () {
      expect(Judge.classify(tapTimeS: 1.0, noteTimeS: 1.049), Judgement.perfect);
      expect(Judge.classify(tapTimeS: 1.0, noteTimeS: 1.111), isNull);
    });
  });

  group('Judge.isAutoMissed', () {
    test('a note is safe until it passes the good window', () {
      expect(Judge.isAutoMissed(noteTimeS: 1.0, songTimeS: 1.110), isFalse);
      expect(Judge.isAutoMissed(noteTimeS: 1.0, songTimeS: 1.111), isTrue);
    });
  });

  group('Judge.pickTargetIndex', () {
    test('picks the earliest unhit note inside the window', () {
      final times = [1.00, 1.05, 1.20];
      final hit = [false, false, false];
      expect(Judge.pickTargetIndex(noteTimesS: times, hit: hit, tapTimeS: 1.02), 0);
    });

    test('skips notes already hit', () {
      final times = [1.00, 1.05];
      final hit = [true, false];
      expect(Judge.pickTargetIndex(noteTimesS: times, hit: hit, tapTimeS: 1.02), 1);
    });

    test('returns null when nothing is in range', () {
      final times = [1.00];
      final hit = [false];
      expect(Judge.pickTargetIndex(noteTimesS: times, hit: hit, tapTimeS: 1.5), isNull);
    });
  });
}
