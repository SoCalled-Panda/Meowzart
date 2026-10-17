import 'package:flutter/material.dart';

/// The flying witch-cat loop at the bottom of the menu.
///
/// Frames are sliced from `Retro cat/WitchFlying.png` by
/// `tools/pipeline/export_ui_art.py`; [frames] must match the number of
/// `witch_fly_*.png` slices it writes.
class WitchFlying extends StatefulWidget {
  const WitchFlying({super.key, this.height = 96, this.frames = 6});

  final double height;
  final int frames;

  @override
  State<WitchFlying> createState() => _WitchFlyingState();
}

class _WitchFlyingState extends State<WitchFlying>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 110 * widget.frames),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final frame =
            (_controller.value * widget.frames).floor() % widget.frames;
        return Image.asset(
          'assets/images/ui/witch_fly_$frame.png',
          height: widget.height,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, __, ___) => SizedBox(height: widget.height),
        );
      },
    );
  }
}
