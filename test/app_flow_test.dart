import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowzart/app.dart';
import 'package:meowzart/audio/audio_service.dart';
import 'package:meowzart/data/chart_repository.dart';
import 'package:meowzart/data/models/chart.dart';
import 'package:meowzart/data/models/result.dart';
import 'package:meowzart/ui/screens/game_screen.dart';
import 'package:meowzart/ui/screens/results_screen.dart';

/// Walks the real screen flow against the real bundled charts:
/// menu → song select → difficulty button → auto-starting loader → run.
///
/// This is the integration gap the widget-free unit tests cannot cover: every
/// step here reads an asset through [rootBundle] and pushes the next screen, so
/// a broken manifest, a renamed chart file or a wrong route name fails here.
///
/// The run itself is checked separately with an un-initialised [AudioService]:
/// SoLoud has no native library under `flutter test`, so the game must fall back
/// to its silent-song clock (see [AudioService.init]) — which is exactly the
/// path that has to survive on a device whose audio engine fails.
Future<Chart> loadFirstChart() async {
  final repo = ChartRepository();
  final songs = await repo.loadManifest();
  return repo.loadChart(songs.first);
}

/// `pumpAndSettle` cannot be used once a Flame [GameWidget] is on screen: the
/// game's ticker keeps requesting frames forever, so settling never happens.
/// Pump a bounded number of frames instead.
Future<void> pumpFrames(WidgetTester tester, {int frames = 24}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('menu → songs → difficulty button starts the real run',
      (tester) async {
    await tester.pumpWidget(const MeowzartApp());
    expect(find.text('Meowzart'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Songs'), findsOneWidget);

    // Every row comes from assets/charts/songs.json.
    final songs = await ChartRepository().loadManifest();
    expect(songs.length, 3);
    for (final song in songs) {
      expect(find.text(song.title), findsOneWidget,
          reason: 'songs.json row ${song.id} must appear on the list');
    }

    // Difficulty lives on the card; tapping it loads that chart's file, and
    // the loader replaces itself with the running game.
    await tester.tap(find.byKey(const ValueKey('start-summer-normal')));
    await pumpFrames(tester, frames: 60);

    expect(find.byWidgetPredicate((w) => w is GameWidget), findsOneWidget,
        reason: 'the difficulty tap must land in a running game');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the run screen builds on the silent-song fallback',
      (tester) async {
    final chart = await loadFirstChart();
    // Deliberately never initialised: available == false, so startSong() and
    // playMeow() are lock-free no-ops and the game drives its own clock.
    final audio = AudioService();
    expect(audio.available, isFalse);

    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        song: (await ChartRepository().loadManifest()).first,
        chart: chart,
        notes: chart.notesFor(Difficulty.easy),
        difficulty: Difficulty.easy,
        audio: audio,
      ),
    ));
    await pumpFrames(tester);

    // Raw `byType(GameWidget)` instantiates to `GameWidget<Game>`, but the
    // screen builds `GameWidget<MeowGame>` — match on the interface instead.
    expect(find.byWidgetPredicate((w) => w is GameWidget), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'the game must survive a dead audio engine');

    // The HUD overlay is live even with no audio: score 0, x1 multiplier.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('x1'), findsOneWidget);

    // Pause is reachable, which also proves the game was ticking.
    await tester.tap(find.byTooltip('Pause'));
    await pumpFrames(tester, frames: 40);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Quit to songs'), findsOneWidget);
  });

  testWidgets('results renders earned and empty star slots from the art',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ResultsScreen(
          result: const RunResult(
            songId: 'summer',
            difficulty: 'normal',
            score: 4200,
            maxCombo: 90,
            perfects: 80,
            goods: 10,
            misses: 3,
            naps: 0,
            accuracy: 0.7, // star_rating's documented two-star case
          ),
          onReplay: () {},
          onSongs: () {},
          onMenu: () {},
        ),
      ),
    ));
    await tester.pump();

    Finder slot(String asset) => find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == asset);

    // 2 earned + 1 empty: both art paths must render, not the fallback glyph.
    expect(slot('assets/images/ui/star_slot_filled.png'), findsNWidgets(2));
    expect(slot('assets/images/ui/star_slot_empty.png'), findsNWidgets(1));

    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('Song list'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
  });
}
