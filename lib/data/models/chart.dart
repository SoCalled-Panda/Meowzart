import 'dart:convert';

Map<String, dynamic> _asObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Each note must be a JSON object');
  }
  return value;
}

/// Numeric field with a default. Non-numeric input falls back rather than
/// throwing a [TypeError] — everything user-supplied should fail as a
/// [FormatException] so the UI has exactly one thing to catch.
double _num(Object? value, {double fallback = 0}) =>
    value is num ? value.toDouble() : fallback;

enum MeowSample { low, lowMid, mid, midHigh, high }

enum Difficulty { easy, normal, hard }

class NoteData {
  NoteData({
    required this.t,
    required this.lane,
    required this.sample,
    required this.shift,
  });

  /// Seconds from the audio start when the note should be hit.
  final double t;

  /// 0..lanes-1
  final int lane;

  final MeowSample sample;

  /// Semitone shift applied to the sample, −5..+5.
  final int shift;

  /// Runtime state. Never serialised.
  bool hit = false;

  factory NoteData.fromJson(Map<String, dynamic> json) {
    final sampleName = json['sample'];
    final sample = MeowSample.values.where((s) => s.name == sampleName).firstOrNull;
    if (sample == null) throw FormatException('Unknown meow sample "$sampleName"');
    final t = json['t'];
    if (t is! num) throw const FormatException('Note "t" must be a number');
    final lane = json['lane'];
    if (lane is! int) throw const FormatException('Note "lane" must be an integer');
    final shift = json['shift'];
    if (shift is! int) throw const FormatException('Note "shift" must be an integer');
    return NoteData(
      t: t.toDouble(),
      lane: lane,
      sample: sample,
      shift: shift,
    );
  }

  Map<String, dynamic> toJson() =>
      {'t': t, 'lane': lane, 'sample': sample.name, 'shift': shift};
}

class DifficultyNotes {
  const DifficultyNotes({required this.minGapMs, required this.notes});

  final int minGapMs;
  final List<NoteData> notes;

  factory DifficultyNotes.fromJson(Map<String, dynamic> json) {
    final minGap = json['min_gap_ms'];
    if (minGap is! int) {
      throw const FormatException('Missing or invalid "min_gap_ms"');
    }
    final rawNotes = json['notes'];
    if (rawNotes is! List) {
      throw const FormatException('Difficulty "notes" must be an array');
    }
    return DifficultyNotes(
      minGapMs: minGap,
      notes: [for (final n in rawNotes) NoteData.fromJson(_asObject(n))],
    );
  }
}

class Chart {
  const Chart({
    required this.id,
    required this.title,
    required this.composer,
    required this.bpm,
    required this.durationS,
    required this.audioPath,
    required this.audioOffsetMs,
    required this.transpose,
    required this.lanes,
    required this.difficulties,
  });

  final String id;
  final String title;
  final String composer;
  final double bpm;
  final double durationS;
  final String audioPath;
  final int audioOffsetMs;

  /// Informational: the backing was already rendered transposed.
  final int transpose;
  final int lanes;
  final Map<Difficulty, DifficultyNotes> difficulties;

  List<NoteData> notesFor(Difficulty d) => difficulties[d]?.notes ?? const [];

  bool get hasEasy => difficulties.containsKey(Difficulty.easy);

  /// Parses and validates a chart. Throws [FormatException] on bad input.
  factory Chart.parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('Chart is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Chart root must be a JSON object');
    }
    return Chart.fromJson(decoded);
  }

  factory Chart.fromJson(Map<String, dynamic> json) {
    String req(String key) {
      final v = json[key];
      if (v is! String || v.isEmpty) throw FormatException('Missing or empty "$key"');
      return v;
    }

    final lanes = json['lanes'];
    if (lanes is! int || lanes <= 0) throw FormatException('Missing or invalid "lanes"');

    final rawDifficulties = json['difficulties'];
    if (rawDifficulties is! Map<String, dynamic> || rawDifficulties.isEmpty) {
      throw const FormatException('Missing "difficulties"');
    }

    final durationS = _num(json['duration_s']);
    if (durationS <= 0) throw const FormatException('Missing or invalid "duration_s"');

    final difficulties = <Difficulty, DifficultyNotes>{};
    for (final entry in rawDifficulties.entries) {
      final difficulty = Difficulty.values.where((d) => d.name == entry.key).firstOrNull;
      if (difficulty == null) throw FormatException('Unknown difficulty "${entry.key}"');
      if (entry.value is! Map<String, dynamic>) {
        throw FormatException('Difficulty "${entry.key}" must be an object');
      }
      difficulties[difficulty] =
          DifficultyNotes.fromJson(entry.value as Map<String, dynamic>);
    }

    final chart = Chart(
      id: req('id'),
      title: req('title'),
      composer: req('composer'),
      bpm: _num(json['bpm']),
      durationS: durationS,
      audioPath: req('audio'),
      audioOffsetMs: _num(json['audio_offset_ms']).round(),
      transpose: _num(json['transpose']).round(),
      lanes: lanes,
      difficulties: difficulties,
    );
    chart._validate();
    return chart;
  }

  void _validate() {
    for (final entry in difficulties.entries) {
      final diff = entry.key;
      final notes = entry.value.notes;
      double? previous;
      for (final n in notes) {
        if (n.t.isNaN || n.t < 0) {
          throw FormatException('${diff.name}: note time out of range');
        }
        if (n.lane < 0 || n.lane >= lanes) {
          throw FormatException('${diff.name}: lane ${n.lane} outside 0..${lanes - 1}');
        }
        if (n.shift < -5 || n.shift > 5) {
          throw FormatException('${diff.name}: shift ${n.shift} outside −5..+5');
        }
        if (previous != null && n.t < previous) {
          throw FormatException('${diff.name}: notes are not sorted by time');
        }
        previous = n.t;
      }
      if (notes.isNotEmpty && notes.last.t > durationS) {
        throw FormatException('${diff.name}: note after end of song');
      }
    }
  }
}
