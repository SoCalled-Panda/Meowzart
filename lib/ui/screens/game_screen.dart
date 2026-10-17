import 'package:flame/game.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../core/theme.dart';
import '../../data/chart_repository.dart';
import '../../data/models/chart.dart';
import '../../data/models/result.dart';
import '../../game/meow_game.dart';
import '../widgets/pixel_icon.dart';
import 'pause_menu.dart';
import 'results_screen.dart';
import 'song_select_screen.dart';

/// The playable run: Flame game + HUD overlay + pause + results.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.song,
    required this.chart,
    required this.notes,
    required this.difficulty,
    required this.audio,
  });

  final SongMeta song;
  final Chart chart;
  final List<NoteData> notes;
  final Difficulty difficulty;
  final AudioService audio;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver {
  late final MeowGame game;
  final ValueNotifier<HudState> hud = ValueNotifier(const HudState());
  double musicVolume = 0.6;
  double meowVolume = 1.0;
  int offsetMs = 0;

  /// Non-null once the song ends: shows the results layer over the game.
  RunResult? result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = MeowGame(
      chart: widget.chart,
      notes: widget.notes,
      difficulty: widget.difficulty,
      audio: widget.audio,
      hud: hud,
      onFinish: onFinish,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stops the song; the shared SoLoud engine stays up for the next run.
    widget.audio.dispose();
    hud.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && game.playing) openPause();
  }

  void onFinish(RunResult runResult) {
    if (!mounted || result != null) return;
    setState(() => result = runResult);
  }

  void replay() {
    setState(() => result = null);
    game.restart();
  }

  /// Leaves the run and returns to the song list. The named song-select route
  /// is the anchor, so this works however deep the run was pushed.
  void quitToSongs() {
    game.setPaused(true);
    Navigator.of(context).popUntil(
      (route) => route.settings.name == SongSelectScreen.routeName ||
          route.isFirst,
    );
  }

  /// All the way out to the main menu.
  void quitToMenu() {
    game.setPaused(true);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// D F J K hints only make sense with a keyboard (desktop smoke tests).
  bool get _showKeyHints =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> openPause() async {
    game.setPaused(true);
    final choice = await showModalBottomSheet<PauseChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PauseMenuSheet(
        musicVolume: musicVolume,
        meowVolume: meowVolume,
        latencyOffsetMs: offsetMs,
      ),
    );
    if (!mounted) return;
    if (choice == null) {
      if (result == null) game.setPaused(false);
      return;
    }
    musicVolume = choice.music;
    meowVolume = choice.meow;
    offsetMs = choice.offsetMs;
    game.applySettings(
        music: choice.music, meow: choice.meow, offsetMs: choice.offsetMs);
    if (choice.restart) {
      replay();
      return;
    }
    if (choice.quit) {
      quitToSongs();
      return;
    }
    if (result == null) game.setPaused(false);
  }

  @override
  Widget build(BuildContext context) {
    final finished = result;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: game)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<HudState>(
                valueListenable: hud,
                builder: (context, h, _) => HudBar(
                  hud: h,
                  onPause: openPause,
                ),
              ),
            ),
            if (finished == null && _showKeyHints)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: IgnorePointer(child: _LaneHints()),
              ),
            if (finished != null)
              Positioned.fill(
                child: ResultsScreen(
                  result: finished,
                  onReplay: replay,
                  onSongs: quitToSongs,
                  onMenu: quitToMenu,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Keyboard hint for desktop smoke testing (D F J K -> lanes 0-3).
class _LaneHints extends StatelessWidget {
  const _LaneHints();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: 0.35,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final key in const ['D', 'F', 'J', 'K'])
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.milkCream),
                ),
                child: Text(key,
                    style: const TextStyle(color: AppColors.milkCream)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Score / combo / mood / pause overlay.
class HudBar extends StatelessWidget {
  const HudBar({super.key, required this.hud, required this.onPause});

  final HudState hud;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.nightPlum.withValues(alpha: 0.92),
            AppColors.nightPlum.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${hud.score}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  hud.combo > 1
                      ? '${hud.combo} combo x${hud.multiplier}'
                      : 'x${hud.multiplier}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.lampAmber),
                ),
              ],
            ),
          ),
          if (hud.judgement.isNotEmpty)
            Text(hud.judgement,
                style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hud.napping ? 'Zzz' : 'Cat',
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Container(
                width: 90,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: AppColors.milkCream.withValues(alpha: 0.2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (hud.mood / 100).clamp(0.0, 1.0),
                    child:
                        Container(decoration: const BoxDecoration(gradient: kMoodGradient)),
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: onPause,
            tooltip: 'Pause',
            icon: const PixelIcon('icon_pause.png',
                size: 28, fallbackIcon: Icons.pause),
          ),
        ],
      ),
    );
  }
}
