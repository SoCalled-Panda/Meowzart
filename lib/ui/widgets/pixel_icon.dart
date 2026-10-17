import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// A pixel-art UI icon from `assets/images/ui/`, sized for buttons and labels.
///
/// Falls back to [fallbackIcon] (drawn in lamp amber) when the asset fails to
/// load, so a missing file degrades to a Material glyph instead of a
/// broken-image placeholder — the same pattern the cat avatars use.
class PixelIcon extends StatelessWidget {
  const PixelIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.fallbackIcon,
  });

  /// File name inside `assets/images/ui/`, e.g. `icon_pause.png`.
  final String asset;

  /// Rendered width and height; the art keeps its own aspect inside.
  final double size;

  /// Material glyph shown when the asset cannot be loaded (null = nothing).
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/ui/$asset',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallbackIcon == null
          ? SizedBox.square(dimension: size)
          : Icon(fallbackIcon, size: size, color: AppColors.lampAmber),
    );
  }
}
