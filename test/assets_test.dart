import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:meowzart/data/chart_repository.dart';
import 'package:meowzart/data/models/chart.dart';

/// Guards the *shipped* assets, i.e. the ones a player actually hears. The
/// pure-Dart tests in `chart_parse_test.dart` prove the parser handles
/// synthetic input; these prove the pipeline's real output is wired into the
/// bundle and still has the shape the game assumes.
///
/// These read through [rootBundle], so they fail loudly if a file is dropped
/// from `pubspec.yaml` (e.g. an accidental whole-dir rename) — the failure mode
/// that a compile-time-clean project does *not* catch.

/// The five meow pitches, in the order `MeowSample` declares them.
const List<String> kLanes = ['low', 'lowMid', 'mid', 'midHigh', 'high'];

/// The one-shot `prep_meows.py` renders for a lane.
String meowWav(String lane) => 'assets/audio/meows/meow_$lane.wav';

/// The raw take the pipeline reads, kept as SoLoud's fallback candidate.
String meowSource(String lane) => 'assets/audio/meows/$lane.mp3';

/// Enough of a RIFF/WAVE reader to assert "16-bit mono PCM, sane length"
/// without adding an audio package to the test dependencies.
class WavInfo {
  const WavInfo._({
    required this.format,
    required this.channels,
    required this.bits,
    required this.sampleRate,
    required this.dataBytes,
  });

  final int format;
  final int channels;
  final int bits;
  final int sampleRate;
  final int dataBytes;

  double get seconds => dataBytes / (channels * (bits ~/ 8)) / sampleRate;

  static WavInfo parse(ByteData data) {
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (bytes.length < 12) fail('WAV is shorter than a RIFF header');
    String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') {
      fail('not a RIFF/WAVE file (got "${tag(0)}"/"${tag(8)}")');
    }
    var format = 0, channels = 0, bits = 0, sampleRate = 0, dataBytes = -1;
    for (var at = 12; at + 8 <= bytes.length;) {
      final id = tag(at);
      final size =
          ByteData.sublistView(bytes, at + 4, at + 8).getUint32(0, Endian.little);
      final body = at + 8;
      if (id == 'fmt ') {
        final fmt = ByteData.sublistView(bytes, body, body + 16);
        format = fmt.getUint16(0, Endian.little);
        channels = fmt.getUint16(2, Endian.little);
        sampleRate = fmt.getUint32(4, Endian.little);
        bits = fmt.getUint16(14, Endian.little);
      } else if (id == 'data') {
        dataBytes = size;
      }
      at = body + size + (size.isOdd ? 1 : 0);
    }
    if (sampleRate == 0 || dataBytes < 0) {
      fail('WAV is missing its fmt or data chunk');
    }
    return WavInfo._(
      format: format,
      channels: channels,
      bits: bits,
      sampleRate: sampleRate,
      dataBytes: dataBytes,
    );
  }
}

/// FNV-1a over the payload: cheap way to prove two one-shots differ.
int fingerprint(ByteData data) {
  var hash = 0x811c9dc5;
  for (final byte
      in data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

Future<ByteData> loadAsset(String path) async {
  try {
    return await rootBundle.load(path);
  } on FlutterError catch (e) {
    fail('asset "$path" is not in the bundle ($e). '
        'Is it covered by the assets: section of pubspec.yaml?');
  }
}

Future<Chart> loadFirstChart() async {
  final repo = ChartRepository();
  final songs = await repo.loadManifest();
  return repo.loadChart(songs.first);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('song manifest', () {
    test('lists the shipped song and every row loads', () async {
      final repo = ChartRepository();
      final songs = await repo.loadManifest();
      expect(songs, isNotEmpty, reason: 'song select would be empty');

      for (final song in songs) {
        final chart = await repo.loadChart(song);
        expect(chart.id, song.id);
        expect(chart.title, song.title);
        expect(chart.composer, song.composer);
      }
    });
  });

  group('summer chart', () {
    test('is a playable four-lane chart for every offered difficulty', () async {
      final chart = await loadFirstChart();

      expect(chart.lanes, 4);
      expect(chart.bpm, greaterThan(0));
      expect(chart.durationS, greaterThan(60));
      expect(chart.audioPath, isNotEmpty);

      // The loader's difficulty picker offers exactly these two.
      expect(chart.difficulties.keys,
          containsAll([Difficulty.easy, Difficulty.normal]));

      for (final entry in chart.difficulties.entries) {
        final diff = entry.value;
        final notes = diff.notes;
        final where = '${entry.key.name}: ';
        expect(notes.length, greaterThan(100),
            reason: '${where}too sparse to play');

        for (var i = 1; i < notes.length; i++) {
          expect((notes[i].t - notes[i - 1].t) * 1000,
              greaterThanOrEqualTo(diff.minGapMs - 0.5),
              reason: '${where}notes ${i - 1}/$i are closer than min_gap_ms');
        }

        // A lane nobody plays is a bug in the quantile mapping, not taste.
        expect(notes.map((n) => n.lane).toSet(), {0, 1, 2, 3},
            reason: '${where}leaves a lane empty');
        expect(notes.map((n) => n.sample).toSet(), MeowSample.values.toSet(),
            reason: '${where}not every recorded lane is used');
      }

      expect(chart.notesFor(Difficulty.normal).length,
          greaterThan(chart.notesFor(Difficulty.easy).length),
          reason: 'Normal must actually be harder than Easy');

      // The pipeline searches transpose −12..+12; hitting the edge means the
      // melody did not fit the sample coverage at any transposition.
      expect(chart.transpose.abs(), lessThan(12),
          reason: 'transposition saturated — add a meow or re-pick the song');
    });
  });

  group('backing track', () {
    test('the chart audio is bundled and is a real Vorbis stream', () async {
      final chart = await loadFirstChart();
      final data = await loadAsset('assets/audio/${chart.audioPath}');

      // A placeholder or truncated render would be orders of magnitude smaller
      // than ~583 KB of three minutes of music at 22.05 kHz mono.
      expect(data.lengthInBytes, greaterThan(100 * 1024),
          reason: 'the backing looks like a stub, not a render');
      expect(
          String.fromCharCodes(data.buffer.asUint8List(data.offsetInBytes, 4)),
          'OggS');
    });
  });

  group('meow one-shots', () {
    test('every lane is a short 16-bit mono PCM one-shot', () async {
      for (final lane in kLanes) {
        final info = WavInfo.parse(await loadAsset(meowWav(lane)));
        final where = 'meow_$lane.wav: ';
        expect(info.format, 1, reason: '${where}PCM expected, got ${info.format}');
        expect(info.channels, 1, reason: '${where}must be mono');
        expect(info.bits, 16, reason: '${where}must be 16-bit');
        expect(info.sampleRate, greaterThanOrEqualTo(22050),
            reason: '${where}pitch detection needs the bandwidth');
        expect(info.seconds, inInclusiveRange(0.12, 0.45),
            reason: '${where}must stay a snappy one-shot (prep_meows MAX_LEN_S)');
      }
    });

    test('every lane is a distinct recording, not a copy', () async {
      final prints = <String, int>{
        for (final lane in kLanes)
          lane: fingerprint(await loadAsset(meowWav(lane))),
      };
      expect(prints.values.toSet(), hasLength(kLanes.length),
          reason: 'two lanes ship byte-identical audio: $prints');
    });

    test('every sample the chart asks for resolves to real audio', () async {
      final chart = await loadFirstChart();
      final used = {
        for (final diff in chart.difficulties.values)
          for (final note in diff.notes) note.sample,
      };
      expect(used, isNotEmpty);

      for (final sample in used) {
        // WAV first, then the raw take: this mirrors AudioService._meowAssets,
        // so a lane the chart plays can never end up silent.
        expect((await loadAsset(meowWav(sample.name))).lengthInBytes,
            greaterThan(4 * 1024));
        await loadAsset(meowSource(sample.name));
      }
    });
  });

  group('UI art', () {
    /// Everything the Flutter UI loads by name. The icons and star slots come
    /// from `tools/pipeline/export_ui_art.py`; keep this list in sync when a
    /// screen adopts a new slice.
    const uiAssets = [
      'assets/images/ui/icon_play.png',
      'assets/images/ui/icon_pause.png',
      'assets/images/ui/icon_gear.png',
      'assets/images/ui/icon_home.png',
      'assets/images/ui/icon_retry.png',
      'assets/images/ui/icon_speaker.png',
      'assets/images/ui/icon_waves.png',
      'assets/images/ui/icon_waves_triple.png',
      'assets/images/ui/star_slot_filled.png',
      'assets/images/ui/star_slot_empty.png',
      'assets/images/ui/song_select_bg.png',
      'assets/images/ui/cover_summer.jpg',
      'assets/images/ui/cover_canon.jpg',
      'assets/images/ui/notes_motif.png',
      'assets/images/ui/hit_line.png',
      'assets/images/ui/witch_fly_0.png',
      'assets/images/ui/witch_fly_1.png',
      'assets/images/ui/witch_fly_2.png',
      'assets/images/ui/witch_fly_3.png',
      'assets/images/ui/witch_fly_4.png',
      'assets/images/ui/witch_fly_5.png',
    ];

    test('every wired UI asset is bundled and has a real image signature',
        () async {
      for (final path in uiAssets) {
        final data = await loadAsset(path);
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        expect(bytes.length, greaterThan(1024),
            reason: '$path looks like a stub');
        if (path.endsWith('.png')) {
          expect(bytes.sublist(0, 8),
              [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
              reason: '$path is not a PNG');
        } else {
          expect(bytes[0], 0xff, reason: '$path is not a JPEG');
          expect(bytes[1], 0xd8, reason: '$path is not a JPEG');
          expect(bytes[2], 0xff, reason: '$path is not a JPEG');
        }
      }
    });
  });

  group('gameplay crew art', () {
    test('the five bottom-row crew cats ship as real PNGs', () async {
      for (final path in const [
        'assets/images/cats/crew_box.png',
        'assets/images/cats/crew_dracula.png',
        'assets/images/cats/crew_idle.png',
        'assets/images/cats/crew_tan.png',
      ]) {
        final data = await loadAsset(path);
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        // Small sprites (32x32 .. 64x45): existence + signature only.
        expect(bytes.length, greaterThan(64), reason: '$path looks empty');
        expect(bytes.sublist(0, 8),
            [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
            reason: '$path is not a PNG');
      }
    });
  });

  group('fonts', () {
    test('the pixel UI font ships with the bundle', () async {
      for (final path in const [
        'assets/fonts/PixelifySans-Regular.ttf',
        'assets/fonts/PixelifySans-Bold.ttf',
      ]) {
        final data = await loadAsset(path);
        expect(data.lengthInBytes, greaterThan(10 * 1024),
            reason: '$path looks like a stub');
        // TrueType sfnt version 00 01 00 00 ('true'/'OTTO' also legal).
        final tag = data.getUint32(0, Endian.big);
        expect(tag == 0x00010000 || tag == 0x74727565 || tag == 0x4f54544f,
            isTrue,
            reason: '$path is not a TrueType/OpenType file');
      }
    });
  });

  group('licenses', () {
    test('every audio asset the game loads has a LICENSES.md row', () async {
      final text = await rootBundle.loadString('assets/LICENSES.md');

      final referenced = <String>[
        for (final meta in await ChartRepository().loadManifest())
          (await ChartRepository().loadChart(meta)).audioPath.split('/').last,
        for (final lane in kLanes) 'meow_$lane.wav',
        for (final lane in kLanes) '$lane.mp3',
      ];
      for (final name in referenced) {
        expect(text.contains(name), isTrue,
            reason: 'assets/LICENSES.md has no row for $name — '
                'nothing ships without recorded provenance');
      }
    });
  });
}

