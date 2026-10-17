import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../meow_game.dart';

/// One lane column: translucent strip and falling tiles.
/// Taps anywhere in the column hit the lane (single-touch per lane).
class LaneComponent extends PositionComponent with TapCallbacks {
  LaneComponent({
    required this.index,
    required double x,
    required double width,
    required this.hitY,
    required this.color,
  }) : super(position: Vector2(x, 0), size: Vector2(width, 10));

  final int index;
  final double hitY;
  final Color color;
  double songT = -kLeadInS;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = Vector2(this.size.x, size.y);
  }

  @override
  void onTapDown(TapDownEvent event) {
    (parent as MeowGame?)?.tapLane(index);
  }

  @override
  void render(Canvas canvas) {
    final game = parent as MeowGame?;
    final h = game?.size.y ?? 800;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, h),
      Paint()..color = const Color(0xFF4A3B6B).withValues(alpha: 0.35),
    );
    if (game == null) return;
    final scroll = kDefaultScrollSpeed;
    final tileS = size.x * 0.8;
    final hasTile = game.images.containsKey('tiles/tile_$index.png');
    for (final n in game.notes) {
      if (n.hit || n.lane != index) continue;
      final y = hitY - (n.t - songT) * scroll;
      if (y < -tileS || y > h + tileS) continue;
      final x = (size.x - tileS) / 2;
      if (hasTile) {
        final img = game.images.fromCache('tiles/tile_$index.png');
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(x, y - tileS / 2, tileS, tileS),
          Paint(),
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y - tileS / 2, tileS, tileS),
            const Radius.circular(12),
          ),
          Paint()..color = color,
        );
      }
    }
  }
}

/// The four small crew cats in a row at the bottom of the playfield,
/// under the paw hit bar. Decorative: a tap in a lane makes the visually
/// nearest cat hop.
class CatCrew extends PositionComponent {
  CatCrew({required this.hitY});

  /// Left-to-right order; must match the `crew_*` files that
  /// `tools/pipeline/slice_sprites.py` writes.
  static const List<String> sprites = [
    'cats/crew_box.png',
    'cats/crew_dracula.png',
    'cats/crew_idle.png',
    'cats/crew_tan.png',
  ];

  final double hitY;
  final List<Rect> _slots = [];
  final List<double> _bob = [];
  final List<int> _laneCat = List<int>.filled(kLaneCount, 0);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
    _layout();
  }

  void _layout() {
    final game = parent as MeowGame?;
    if (game == null) return;
    final n = sprites.length;
    _bob
      ..clear()
      ..addAll(List<double>.filled(n, 0));
    _slots.clear();
    final aspects = <double>[];
    for (final s in sprites) {
      // MeowGame loads the crew in onLoad before adding this component.
      if (!game.images.containsKey(s)) return;
      final img = game.images.fromCache(s);
      aspects.add(img.width / img.height);
    }
    // Vertical band: below the paw hit bar, down to the bottom edge.
    final laneW = size.x / kLaneCount;
    final bandTop = hitY + 38;
    final bandBottom = size.y - 16;
    final bandH = math.max(0.0, bandBottom - bandTop);
    final sumAsp = aspects.fold<double>(0, (a, b) => a + b);
    const gap = 6.0;
    // Height: fit the band, the width budget, and a "minimal" size cap.
    var h = math.min(bandH, 96.0);
    if (sumAsp > 0) {
      h = math.min(h, (size.x - 16 - gap * (n - 1)) / sumAsp);
    }
    var totalW = gap * (n - 1);
    for (final a in aspects) {
      totalW += a * h;
    }
    var x = (size.x - totalW) / 2;
    for (var i = 0; i < n; i++) {
      final w = aspects[i] * h;
      _slots.add(Rect.fromLTWH(x, bandBottom - h, w, h)); // sit on the edge
      x += w + gap;
    }
    // Each lane's tap bobs the cat nearest to that lane's centre.
    for (var lane = 0; lane < kLaneCount; lane++) {
      final cx = (lane + 0.5) * laneW;
      var best = 0;
      var bestD = double.infinity;
      for (var i = 0; i < _slots.length; i++) {
        final d = (_slots[i].center.dx - cx).abs();
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      _laneCat[lane] = best;
    }
  }

  /// Bob the cat that watches [lane]; called from judgement feedback.
  void react(int lane) {
    if (lane >= 0 && lane < _laneCat.length && lane < _bob.length) {
      _bob[_laneCat[lane]] = 0.3;
    }
  }

  /// Back to rest (Replay / Restart).
  void resetPose() {
    for (var i = 0; i < _bob.length; i++) {
      _bob[i] = 0;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (var i = 0; i < _bob.length; i++) {
      if (_bob[i] > 0) _bob[i] = math.max(0, _bob[i] - dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final game = parent as MeowGame?;
    if (game == null) return;
    final paint = Paint()..filterQuality = FilterQuality.none;
    for (var i = 0; i < _slots.length && i < sprites.length; i++) {
      final s = sprites[i];
      if (!game.images.containsKey(s)) continue;
      final img = game.images.fromCache(s);
      final r = _slots[i];
      final k = _bob[i] / 0.3; // 1 -> 0 across the bob window
      final dy = -math.sin(k * math.pi) * r.height * 0.18;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        r.translate(0, dy),
        paint,
      );
    }
  }
}

/// The full-width paw-print hit bar. Drawn once, after the lanes and before
/// the cats, so its paws line up with the lane centres.
class HitLineBar extends PositionComponent {
  HitLineBar({required this.hitY});

  final double hitY;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = Vector2(size.x, 0);
  }

  @override
  void render(Canvas canvas) {
    final game = parent as MeowGame?;
    if (game == null || !game.images.containsKey('ui/hit_line.png')) return;
    final img = game.images.fromCache('ui/hit_line.png');
    final h = math.min(size.x * img.height / img.width, 64.0);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, hitY - h / 2, size.x, h),
      Paint(),
    );
  }
}
