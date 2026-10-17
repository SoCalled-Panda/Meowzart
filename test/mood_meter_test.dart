import 'package:flutter_test/flutter_test.dart';
import 'package:meowzart/game/logic/judge.dart';
import 'package:meowzart/game/logic/mood_meter.dart';

void main() {
  group('deltas and clamping', () {
    test('starts at 60', () {
      expect(MoodMeter().value, 60);
    });

    test('perfect +2, good +1, miss -6', () {
      final mood = MoodMeter()..value = 50;
      mood.apply(Judgement.perfect);
      expect(mood.value, 52);
      mood.apply(Judgement.good);
      expect(mood.value, 53);
      mood.apply(Judgement.miss);
      expect(mood.value, 47);
    });

    test('clamps at 100', () {
      final mood = MoodMeter()..value = 99;
      mood.apply(Judgement.perfect);
      expect(mood.value, 100);
      mood.apply(Judgement.good);
      expect(mood.value, 100);
    });

    test('clamps at 0 and falls asleep', () {
      final mood = MoodMeter()..value = 3;
      mood.apply(Judgement.miss);
      expect(mood.value, 0);
      expect(mood.isNapping, isTrue);
      expect(mood.napCount, 1);
    });
  });

  group('nap cycle', () {
    MoodMeter nappingMeter() => MoodMeter()..value = 3;

    test('scoring is frozen while asleep', () {
      final mood = nappingMeter()..apply(Judgement.miss);
      expect(mood.scoringPaused, isTrue);
      expect(mood.apply(Judgement.perfect), isFalse);
      expect(mood.value, 0);
    });

    test('wakes at mood 30 after 5 seconds', () {
      final mood = nappingMeter()..apply(Judgement.miss);
      mood.update(2);
      expect(mood.isNapping, isTrue);
      mood.update(3);
      expect(mood.isNapping, isFalse);
      expect(mood.value, 30);
      expect(mood.apply(Judgement.perfect), isTrue);
      expect(mood.value, 32);
    });

    test('the nap timer does not run while awake', () {
      final mood = MoodMeter()..value = 50;
      mood.update(100);
      expect(mood.value, 50);
      expect(mood.isNapping, isFalse);
    });

    test('every sleep counts, so the star rating can cap at 2', () {
      final mood = nappingMeter()..apply(Judgement.miss);
      mood.update(5);
      mood.value = 3;
      mood.apply(Judgement.miss);
      expect(mood.napCount, 2);
    });

    test('reset clears the nap count', () {
      final mood = nappingMeter()..apply(Judgement.miss);
      mood.reset();
      expect(mood.napCount, 0);
      expect(mood.value, 60);
      expect(mood.isNapping, isFalse);
    });
  });

  group('fraction', () {
    test('maps 0..100 to 0..1', () {
      expect((MoodMeter()..value = 0).fraction, 0);
      expect((MoodMeter()..value = 50).fraction, 0.5);
      expect((MoodMeter()..value = 100).fraction, 1);
    });
  });
}
