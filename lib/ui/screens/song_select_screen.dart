import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/chart_repository.dart';
import '../../data/models/chart.dart';
import '../widgets/pixel_icon.dart';
import 'chart_loader_screen.dart';

/// Lists `assets/charts/songs.json`. Each card shows the song's cover art and
/// carries the difficulty buttons: tapping one loads the chart and starts the
/// run (no separate partner / difficulty screens).
class SongSelectScreen extends StatefulWidget {
  const SongSelectScreen({super.key});

  /// Named route: `GameScreen` pops back here when the player quits a run.
  static const String routeName = 'song_select';

  @override
  State<SongSelectScreen> createState() => _SongSelectScreenState();
}

class _SongSelectScreenState extends State<SongSelectScreen> {
  late final Future<List<SongMeta>> _songs;

  @override
  void initState() {
    super.initState();
    _songs = ChartRepository().loadManifest();
  }

  void _start(SongMeta song, Difficulty difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChartLoaderScreen(song: song, difficulty: difficulty),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Songs')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/ui/song_select_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          // Keeps the song cards readable over the record-shelf art.
          ColoredBox(color: AppColors.nightPlum.withValues(alpha: 0.45)),
          FutureBuilder<List<SongMeta>>(
            future: _songs,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorView(
                  message: 'Could not load the song list.',
                  onRetry: () =>
                      setState(() => _songs = ChartRepository().loadManifest()),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final songs = snapshot.data!;
              if (songs.isEmpty) {
                return const Center(child: Text('No songs yet.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: songs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) => _SongCard(
                  song: songs[i],
                  onStart: (difficulty) => _start(songs[i], difficulty),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song, required this.onStart});

  final SongMeta song;
  final ValueChanged<Difficulty> onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppColors.duskViolet, AppColors.nightPlum],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.milkCream.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cover(song: song),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title, style: text.titleLarge),
                const SizedBox(height: 2),
                Text(
                  song.composer,
                  style: text.bodyMedium?.copyWith(color: AppColors.lampAmber),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: ValueKey('start-${song.id}-easy'),
                        onPressed: () => onStart(Difficulty.easy),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: AppColors.milkCream.withValues(alpha: 0.55),
                          ),
                          textStyle: const TextStyle(
                              fontFamily: AppTheme.fontFamily, fontSize: 15),
                        ),
                        child: const Text('Easy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: ValueKey('start-${song.id}-normal'),
                        onPressed: () => onStart(Difficulty.normal),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                              fontFamily: AppTheme.fontFamily, fontSize: 15),
                        ),
                        icon: const PixelIcon('icon_play.png',
                            size: 18, fallbackIcon: Icons.play_arrow),
                        label: const Text('Normal'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The song's cover thumbnail, or a note glyph when the manifest has none.
class _Cover extends StatelessWidget {
  const _Cover({required this.song});

  final SongMeta song;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.milkCream.withValues(alpha: 0.3)),
        color: AppColors.nightPlum,
      ),
      clipBehavior: Clip.antiAlias,
      child: song.cover.isEmpty
          ? const Icon(Icons.music_note,
              color: AppColors.lampAmber, size: 36)
          : Image.asset(
              'assets/images/ui/${song.cover}',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.music_note,
                color: AppColors.lampAmber,
                size: 36,
              ),
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
