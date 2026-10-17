import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../data/chart_repository.dart';
import '../../data/models/chart.dart';
import 'game_screen.dart';

/// Loads the chart for the picked song + difficulty, then hands over to the
/// run. Auto-starts: difficulty is chosen on the song card, so this is only
/// the asset-loading step, not a picker.
class ChartLoaderScreen extends StatefulWidget {
  const ChartLoaderScreen({
    super.key,
    required this.song,
    required this.difficulty,
  });

  final SongMeta song;
  final Difficulty difficulty;

  @override
  State<ChartLoaderScreen> createState() => _ChartLoaderScreenState();
}

class _ChartLoaderScreenState extends State<ChartLoaderScreen> {
  late Future<Chart> _chart;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _chart = ChartRepository().loadChart(widget.song);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Chart>(
        future: _chart,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load this chart.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to songs'),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasData && !_started) {
            _started = true;
            // Hand over once this frame settles.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _launch(snapshot.data!),
            );
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('${widget.song.title} — ${widget.difficulty.name}'),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _launch(Chart chart) async {
    // Shared engine: the first run initialises SoLoud, later runs reuse it.
    final audio = AudioService.instance;
    await audio.ensureReady();
    if (!mounted) return;
    // Replacement: backing out of the run returns to the song list.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          song: widget.song,
          chart: chart,
          notes: chart.notesFor(widget.difficulty),
          difficulty: widget.difficulty,
          audio: audio,
        ),
      ),
    );
  }
}
