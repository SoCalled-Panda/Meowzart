import 'package:flutter_test/flutter_test.dart';
import 'package:meowzart/game/logic/star_rating.dart';

void main() {
  group('StarRating.compute', () {
    test('finishing alone earns 1 star', () {
      expect(StarRating.compute(accuracy: 0.0, napCount: 0), 1);
      expect(StarRating.compute(accuracy: 0.699, napCount: 0), 1);
    });

    test('70% earns 2 stars', () {
      expect(StarRating.compute(accuracy: 0.70, napCount: 0), 2);
      expect(StarRating.compute(accuracy: 0.899, napCount: 0), 2);
    });

    test('90% with no nap earns 3 stars', () {
      expect(StarRating.compute(accuracy: 0.90, napCount: 0), 3);
      expect(StarRating.compute(accuracy: 1.0, napCount: 0), 3);
    });

    test('any nap caps the result at 2 stars', () {
      expect(StarRating.compute(accuracy: 1.0, napCount: 1), 2);
      expect(StarRating.compute(accuracy: 0.95, napCount: 3), 2);
    });

    test('a nap never drops below 2 if accuracy holds', () {
      expect(StarRating.compute(accuracy: 0.70, napCount: 2), 2);
    });
  });
}
