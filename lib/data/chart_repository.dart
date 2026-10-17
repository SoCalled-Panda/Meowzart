import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'models/chart.dart';

/// A row from `assets/charts/songs.json`.
class SongMeta {
  const SongMeta({
    required this.id,
    required this.file,
    required this.title,
    required this.composer,
    required this.cover,
    required this.background,
  });

  final String id;
  final String file;
  final String title;
  final String composer;
  final String cover;
  final String background;

  factory SongMeta.fromJson(Map<String, dynamic> json) => SongMeta(
        id: json['id'] as String,
        file: json['file'] as String,
        title: json['title'] as String,
        composer: json['composer'] as String,
        cover: (json['cover'] as String?) ?? '',
        background: (json['background'] as String?) ?? '',
      );
}

/// Reads charts from the asset bundle. Throws a friendly error on bad content —
/// the UI must catch it and return to song select, never crash.
class ChartRepository {
  ChartRepository({this.assetBundle});

  /// Injectable for tests; defaults to [rootBundle].
  final AssetBundle? assetBundle;

  AssetBundle get _bundle => assetBundle ?? rootBundle;

  static const String manifestPath = 'assets/charts/songs.json';

  /// Reads and UTF-8-decodes an asset without [AssetBundle.loadString].
  ///
  /// `loadString` decodes assets over 50 KB through `compute()`, i.e. a
  /// separate isolate — and an isolate result never reaches a continuation
  /// scheduled inside `flutter test`'s fake-async zone, so every widget test
  /// that loads a chart (summer.json is 106 KB) deadlocks on the spinner.
  /// Decoding inline is microseconds and keeps tests and device on one path.
  Future<String> _loadString(String key) async {
    final data = await _bundle.load(key);
    return utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  Future<List<SongMeta>> loadManifest() async {
    final raw = await _loadString(manifestPath);
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('songs.json must be a JSON array');
    }
    return [
      for (final e in decoded) SongMeta.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Throws [FlutterError] if the asset is missing and [FormatException] if the
  /// content is invalid — the UI catches both and returns to song select.
  Future<Chart> loadChart(SongMeta meta) async {
    final raw = await _loadString('assets/charts/${meta.file}');
    return Chart.parse(raw);
  }
}
