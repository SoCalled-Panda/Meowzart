import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/cat.dart';
import '../../data/models/result.dart';
import '../widgets/cat_avatar.dart';
import '../widgets/pixel_icon.dart';

/// End-of-run summary. Drawn as an opaque layer *inside* [GameScreen] rather
/// than pushed as a route, so Replay is a game reset instead of a navigation
/// dance (and the Flutter/Flame widget never has to be rebuilt from scratch).
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.result,
    required this.onReplay,
    required this.onSongs,
    required this.onMenu,
  });

  final RunResult result;
  final VoidCallback onReplay;
  final VoidCallback onSongs;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: AppColors.nightPlum.withValues(alpha: 0.96),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final cat in Cats.all)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: CatAvatar(asset: cat.sprite('happy'), size: 64),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Image.asset(
                        i < result.stars
                            ? 'assets/images/ui/star_slot_filled.png'
                            : 'assets/images/ui/star_slot_empty.png',
                        height: 96,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.star_rounded,
                          size: 44,
                          color: i < result.stars
                              ? AppColors.starGold
                              : AppColors.starEmpty,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${result.score}',
                style: theme.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Accuracy ${(result.accuracy * 100).toStringAsFixed(1)}% · '
                'Max combo ${result.maxCombo}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Perfect ${result.perfects} · Good ${result.goods} · '
                'Miss ${result.misses}'
                '${result.naps > 0 ? ' · Naps ${result.naps}' : ''}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.lampAmber),
              ),
              const Spacer(flex: 2),
              FilledButton.icon(
                onPressed: onReplay,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const PixelIcon('icon_retry.png',
                    size: 24, fallbackIcon: Icons.replay),
                label: const Text('Replay'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSongs,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Song list'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onMenu,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const PixelIcon('icon_home.png',
                          size: 24, fallbackIcon: Icons.home),
                      label: const Text('Menu'),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
