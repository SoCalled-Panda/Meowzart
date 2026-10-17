import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowzart/data/models/chart.dart';

Map<String, dynamic> note(num t, int lane, String sample, int shift) =>
    {'t': t, 'lane': lane, 'sample': sample, 'shift': shift};

Map<String, dynamic> chartJson({
  Object? id = 'canon',
  num durationS = 100,
  int lanes = 4,
  Object? difficulties,
}) =>
    {
      'version': 1,
      if (id != null) 'id': id,
      'title': 'Canon in D',
      'composer': 'Johann Pachelbel',
      'bpm': 72.0,
      'duration_s': durationS,
      'audio': 'songs/canon.ogg',
      'audio_offset_ms': 0,
      'transpose': 0,
      'lanes': lanes,
      'difficulties': difficulties ??
          {
            'easy': {
              'min_gap_ms': 350,
              'notes': [
                note(1.0, 0, 'low', 0),
                note(1.5, 3, 'mid', -2),
                note(2.0, 1, 'high', 5),
              ],
            },
          },
    };

String encode(Map<String, dynamic> json) => jsonEncode(json);

void main() {
  group('Chart.parse happy path', () {
    test('parses header and notes', () {
      final chart = Chart.parse(encode(chartJson()));
      expect(chart.id, 'canon');
      expect(chart.lanes, 4);
      expect(chart.transpose, 0);
      expect(chart.audioPath, 'songs/canon.ogg');
      expect(chart.hasEasy, isTrue);

      final notes = chart.notesFor(Difficulty.easy);
      expect(notes, hasLength(3));
      expect(notes.first.lane, 0);
      expect(notes.first.sample, MeowSample.low);
      expect(notes.last.sample, MeowSample.high);
      expect(notes.last.shift, 5);
      expect(notes.map((n) => n.t), [1.0, 1.5, 2.0]);
    });

    test('runtime hit flags are not read from json', () {
      final chart = Chart.parse(encode(chartJson()));
      expect(chart.notesFor(Difficulty.easy).every((n) => !n.hit), isTrue);
    });
  });

  group('Chart.parse validation', () {
    void bad(Map<String, dynamic> json) {
      expect(
        () => Chart.parse(encode(json)),
        throwsA(isA<FormatException>()),
        reason: 'expected ${encode(json)} to be rejected',
      );
    }

    test('rejects non-JSON', () {
      expect(() => Chart.parse('not json'), throwsFormatException);
    });

    test('rejects a non-object root', () {
      expect(() => Chart.parse('[]'), throwsFormatException);
    });

    test('rejects missing id', () => bad(chartJson(id: null)));

    test('rejects missing difficulties', () => bad(chartJson(difficulties: {})));

    test('rejects an unknown difficulty name', () {
      bad(chartJson(difficulties: {
        'expert': {'min_gap_ms': 100, 'notes': <Object>[]},
      }));
    });

    test('rejects unsorted notes', () {
      bad(chartJson(difficulties: {
        'easy': {
          'min_gap_ms': 350,
          'notes': [note(2.0, 0, 'low', 0), note(1.0, 1, 'low', 0)],
        },
      }));
    });

    test('rejects a lane outside the range', () {
      bad(chartJson(difficulties: {
        'easy': {
          'min_gap_ms': 350,
          'notes': [note(1.0, 9, 'low', 0)],
        },
      }));
    });

    test('rejects a shift beyond +/-5', () {
      bad(chartJson(difficulties: {
        'easy': {
          'min_gap_ms': 350,
          'notes': [note(1.0, 0, 'low', 9)],
        },
      }));
    });

    test('rejects a note after the end of the song', () {
      bad(chartJson(durationS: 5, difficulties: {
        'easy': {
          'min_gap_ms': 350,
          'notes': [note(6.0, 0, 'low', 0)],
        },
      }));
    });

    test('rejects a negative note time', () {
      bad(chartJson(difficulties: {
        'easy': {
          'min_gap_ms': 350,
          'notes': [note(-1.0, 0, 'low', 0)],
        },
      }));
    });

    test('rejects an unknown meow sample', () {
      bad(chartJson(difficulties: {
        'easy': {
          'min_gap_ms': 350,
          'notes': [note(1.0, 0, 'squeak', 0)],
        },
      }));
    });
  });
}
