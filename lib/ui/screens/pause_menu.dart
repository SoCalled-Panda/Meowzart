import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../widgets/pixel_icon.dart';

/// Pause menu: resume / restart / quit + volumes + offset slider (PRD §2).
class PauseMenuSheet extends StatefulWidget {
  const PauseMenuSheet({
    super.key,
    required this.musicVolume,
    required this.meowVolume,
    required this.latencyOffsetMs,
  });

  final double musicVolume;
  final double meowVolume;
  final int latencyOffsetMs;

  @override
  State<PauseMenuSheet> createState() => _PauseMenuSheetState();
}

class _PauseMenuSheetState extends State<PauseMenuSheet> {
  late double _music = widget.musicVolume;
  late double _meow = widget.meowVolume;
  late double _offset = widget.latencyOffsetMs.toDouble();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const PixelIcon('icon_gear.png',
                    size: 24, fallbackIcon: Icons.settings),
                const SizedBox(width: 8),
                Text('Paused',
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 16),
            _SliderLabel('Music volume ${(_music * 100).round()}%',
                asset: 'icon_speaker.png', fallback: Icons.volume_up),
            Slider(value: _music, onChanged: (v) => setState(() => _music = v)),
            _SliderLabel('Meow volume ${(_meow * 100).round()}%',
                asset: 'icon_waves.png', fallback: Icons.pets),
            Slider(value: _meow, onChanged: (v) => setState(() => _meow = v)),
            _SliderLabel('Timing offset ${_offset.round()} ms',
                asset: 'icon_waves_triple.png', fallback: Icons.tune),
            Slider(
              value: _offset,
              min: -100,
              max: 100,
              divisions: 40,
              onChanged: (v) => setState(() => _offset = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                PauseChoice.resume(
                    music: _music, meow: _meow, offsetMs: _offset.round()),
              ),
              icon: const PixelIcon('icon_play.png',
                  size: 24, fallbackIcon: Icons.play_arrow),
              label: const Text('Resume'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(
                PauseChoice.restart(
                    music: _music, meow: _meow, offsetMs: _offset.round()),
              ),
              icon: const PixelIcon('icon_retry.png',
                  size: 24, fallbackIcon: Icons.refresh),
              label: const Text('Restart'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                PauseChoice.quit(
                    music: _music, meow: _meow, offsetMs: _offset.round()),
              ),
              child: const Text('Quit to songs'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slider caption with its pixel-art icon (speaker, meow waves, beat waves).
class _SliderLabel extends StatelessWidget {
  const _SliderLabel(this.label, {required this.asset, required this.fallback});

  final String label;
  final String asset;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PixelIcon(asset, size: 20, fallbackIcon: fallback),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

/// What the pause sheet returns. Also carries the HUD state type.
enum PauseAction { resume, restart, quit }

class PauseChoice {
  const PauseChoice._(this.action, this.music, this.meow, this.offsetMs);

  const PauseChoice.resume(
      {required double music, required double meow, required int offsetMs})
      : this._(PauseAction.resume, music, meow, offsetMs);

  const PauseChoice.restart(
      {required double music, required double meow, required int offsetMs})
      : this._(PauseAction.restart, music, meow, offsetMs);

  const PauseChoice.quit(
      {required double music, required double meow, required int offsetMs})
      : this._(PauseAction.quit, music, meow, offsetMs);

  final PauseAction action;
  final double music;
  final double meow;
  final int offsetMs;

  bool get restart => action == PauseAction.restart;
  bool get quit => action == PauseAction.quit;
}

/// HUD state pushed from the game to the Flutter overlay.
class HudState {
  const HudState({
    this.score = 0,
    this.combo = 0,
    this.multiplier = 1,
    this.mood = kMoodStart,
    this.napping = false,
    this.judgement = '',
    this.songT = 0,
    this.durationS = 1,
  });

  final int score;
  final int combo;
  final int multiplier;
  final double mood;
  final bool napping;
  final String judgement;
  final double songT;
  final double durationS;
}
