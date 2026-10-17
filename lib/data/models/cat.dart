class CatDef {
  const CatDef({
    required this.id,
    required this.name,
    required this.description,
    required this.look,
    this.unlockStars = 0,
  });

  final String id;
  final String name;
  final String description;
  final String look;

  /// 0 = free. The MVP ships every cat free; this stays for post-MVP unlocks.
  final int unlockStars;

  /// Sprite files are `cats/{id}_{state}.png` with states idle / happy /
  /// sleepy / hero. `hero` is a single-frame portrait for cards.
  String sprite(String state) => 'cats/${id}_$state.png';
}

abstract final class Cats {
  static const CatDef miso = CatDef(
    id: 'lane_0',
    name: 'Miso',
    description: 'Cheerful, always first to sing.',
    look: 'Cream cat, pink cheeks, tail conductor',
  );

  static const CatDef luna = CatDef(
    id: 'lane_1',
    name: 'Luna',
    description: 'Calm and a little mysterious.',
    look: 'Cream cat in a dracula cape',
  );

  static const CatDef bandit = CatDef(
    id: 'lane_2',
    name: 'Bandit',
    description: 'Masked mischief-maker with tiny fangs.',
    look: 'Cream cat in a red bandit mask',
  );

  static const CatDef mochi = CatDef(
    id: 'lane_3',
    name: 'Mochi',
    description: 'Sweet, soft, and half asleep already.',
    look: 'Cream cat peeking from a box',
  );

  static const List<CatDef> all = [miso, luna, bandit, mochi];

  static CatDef byId(String id) => all.firstWhere(
        (c) => c.id == id,
        orElse: () => miso,
      );
}
