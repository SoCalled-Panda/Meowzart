import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Round cat portrait with a pixel-art-safe fallback icon.
class CatAvatar extends StatelessWidget {
  const CatAvatar({super.key, required this.asset, this.size = 64});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.duskViolet,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/$asset',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.pets,
          color: AppColors.lampAmber,
          size: 36,
        ),
      ),
    );
  }
}
