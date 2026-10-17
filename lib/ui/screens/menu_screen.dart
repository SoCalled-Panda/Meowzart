import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../widgets/pixel_icon.dart';
import '../widgets/witch_flying.dart';
import 'song_select_screen.dart';

/// Menu with the Summer cover hero. Settings lives in pause (PRD §2).
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  /// Named route: the root of the app.
  static const String routeName = '/';

  /// Hero size: most of the screen width on phones, also capped by height so
  /// short surfaces (the 800x600 test window) never overflow the column.
  static double _coverSide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return math.min(size.width * 0.82, math.min(340, size.height * 0.42));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Container(
                width: _coverSide(context),
                height: _coverSide(context),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.milkCream.withValues(alpha: 0.25),
                    width: 3,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/ui/cover_summer.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.pets,
                    size: 96,
                    color: AppColors.lampAmber,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Meowzart',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Play classical music by meowing.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.lampAmber,
                    ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.of(context)
                    .pushNamed(SongSelectScreen.routeName),
                icon: const PixelIcon('icon_play.png',
                    size: 26, fallbackIcon: Icons.play_arrow),
                label: const Text('Play'),
              ),
              const Spacer(),
              const WitchFlying(height: 128),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
