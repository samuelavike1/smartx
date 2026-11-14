import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/game/speed_game.dart';

enum OddShape {
  circle('circle'),
  square('square'),
  triangle('triangle');

  const OddShape(this.word);
  final String word;
}

/// Tile colours. Ink and blue are the everyday tiles; orange is only ever
/// the odd one, and differs from both in brightness as well as hue, so it
/// stands out for colour-blind players too.
enum OddTint {
  ink('black', Color(0xFF16161D), Color(0xFFF3F2F7)),
  blue('blue', Color(0xFF2563EB), Color(0xFF5B8DEF)),
  orange('orange', Color(0xFFE06C00), Color(0xFFF5A04A));

  const OddTint(this.word, this.color, this.nightColor);
  final String word;
  final Color color;

  /// At night the black tiles turn near-white and the others brighten,
  /// keeping the same brightness order (so it still works colour-blind).
  final Color nightColor;

  Color shade({required bool night}) => night ? nightColor : color;
}

/// The one way the odd tile differs from the rest.
enum OddFeature {
  colour('colour'),
  shape('shape'),
  turn('turn'),
  size('size');

  const OddFeature(this.word);
  final String word;
}

const _turnWords = ['up', 'right', 'down', 'left'];

@immutable
class OddTile {
  const OddTile({
    required this.shape,
    required this.tint,
    this.turn = 0,
    this.scale = 1,
  });

  final OddShape shape;
  final OddTint tint;

  /// Quarter turns clockwise from pointing up (only shows on triangles).
  final int turn;

  /// Glyph size relative to a normal tile.
  final double scale;

  bool get small => scale < 1;
  String get pointing => 'pointing ${_turnWords[turn % 4]}';

  /// For screen readers: "small orange triangle pointing down".
  String get description => [
    if (small) 'small',
    tint.word,
    shape.word,
    if (shape == OddShape.triangle) pointing,
  ].join(' ');
}

/// A grid of [side]×[side] tiles; all alike except the one at [odd].
@immutable
class OddTrial implements SpeedTrial<int> {
  const OddTrial({
    required this.side,
    required this.tiles,
    required this.odd,
    required this.feature,
  });

  final int side;
  final List<OddTile> tiles;
  final int odd;
  final OddFeature feature;

  @override
  int get answer => odd;

  /// An odd colour pops out at once; anything else has to be searched for.
  @override
  bool get conflict => feature != OddFeature.colour;

  String place(int i) => 'row ${i ~/ side + 1}, column ${i % side + 1}';

  /// What makes the odd one odd: "the only circle".
  String get why {
    final t = tiles[odd];
    return switch (feature) {
      OddFeature.colour => 'the only ${t.tint.word} one',
      OddFeature.shape => 'the only ${t.shape.word}',
      OddFeature.turn => 'the only triangle ${t.pointing}',
      OddFeature.size => 'the only smaller one',
    };
  }
}

@immutable
class OddDifficulty {
  const OddDifficulty({
    required this.side,
    required this.colourShare,
    required this.hidden,
    required this.limitMs,
    this.smallScale = 0.72,
    this.mixedTints = false,
  });

  factory OddDifficulty.forLevel(int level) => switch (level.clamp(1, 10)) {
    <= 2 => const OddDifficulty(
      side: 3,
      colourShare: 0.5,
      hidden: [OddFeature.shape],
      limitMs: 4000,
    ),
    <= 4 => const OddDifficulty(
      side: 4,
      colourShare: 0.4,
      hidden: [OddFeature.shape, OddFeature.turn],
      limitMs: 3500,
    ),
    <= 6 => const OddDifficulty(
      side: 4,
      colourShare: 0.3,
      hidden: [OddFeature.shape, OddFeature.turn, OddFeature.size],
      limitMs: 3000,
    ),
    <= 8 => const OddDifficulty(
      side: 5,
      colourShare: 0.25,
      hidden: [OddFeature.shape, OddFeature.turn, OddFeature.size],
      smallScale: 0.82,
      limitMs: 3500,
    ),
    _ => const OddDifficulty(
      side: 5,
      colourShare: 0.25,
      hidden: [OddFeature.shape, OddFeature.turn, OddFeature.size],
      smallScale: 0.82,
      mixedTints: true,
      limitMs: 3000,
    ),
  };

  /// Tiles per row and column.
  final int side;

  /// Share of grids where the odd one differs in colour.
  final double colourShare;

  /// The other ways the odd one may differ.
  final List<OddFeature> hidden;

  /// Size of the odd one when it differs in size.
  final double smallScale;

  /// The ordinary tiles come in two colours (ink and blue).
  final bool mixedTints;

  /// Time limit per grid, in milliseconds.
  final int limitMs;

  List<OddFeature> get features => [OddFeature.colour, ...hidden];

  static const int grids = 12;

  /// A block passes at this many right.
  static const int passMark = 10;
}

typedef OddAnswer = SpeedAnswer<int>;

@immutable
class OddBlock extends SpeedBlock<OddTrial, int> {
  const OddBlock({
    required this.level,
    required this.seed,
    required this.trials,
    required this.limit,
    required this.features,
  });

  @override
  final int level;
  @override
  final int seed;
  @override
  final List<OddTrial> trials;

  /// Time allowed per grid.
  @override
  final Duration limit;

  /// The ways an odd one may differ at this level.
  final List<OddFeature> features;

  @override
  int get passMark => OddDifficulty.passMark;

  @override
  OddBlock withTrials(List<OddTrial> trials) => OddBlock(
    level: level,
    seed: seed,
    trials: trials,
    limit: limit,
    features: features,
  );

  @override
  String get conflictName => 'Odd shapes, turns and sizes';

  @override
  String get noCostSentence => 'Searching didn\'t slow you down.';

  /// The first grid answered wrongly (or not at all), or −1.
  int firstMiss(SpeedResult r) => r.correct.indexOf(false);

  @override
  String mistake(SpeedResult r, List<OddAnswer> answers) {
    final first = firstMiss(r);
    if (first < 0) return 'All $length right.';
    final t = trials[first];
    final a = first < answers.length ? answers[first] : null;
    final odd = 'the odd one was in ${t.place(t.odd)}, ${t.why}.';
    return a?.tapped == null
        ? 'Grid ${first + 1} ran out of time: $odd'
        : 'Grid ${first + 1}: $odd';
  }
}

/// Builds blocks from a seed, always with some odd colours and some odd
/// shapes/turns/sizes (so the search cost can be measured), and never the
/// odd one in the same spot twice running.
class OddGenerator {
  const OddGenerator();

  OddBlock generate({required int level, required int seed}) {
    final rng = Random(seed);
    final d = OddDifficulty.forLevel(level);

    while (true) {
      final trials = <OddTrial>[];
      var last = -1;
      for (var i = 0; i < OddDifficulty.grids; i++) {
        final t = _trial(d, rng, avoid: last);
        trials.add(t);
        last = t.odd;
      }
      final colours = trials.where((t) => !t.conflict).length;
      final hidden = trials.length - colours;
      if (colours >= 3 && hidden >= 3) {
        return OddBlock(
          level: level,
          seed: seed,
          trials: trials,
          limit: Duration(milliseconds: d.limitMs),
          features: d.features,
        );
      }
    }
  }

  OddTrial _trial(OddDifficulty d, Random rng, {required int avoid}) {
    final count = d.side * d.side;
    var odd = rng.nextInt(count);
    while (odd == avoid) {
      odd = rng.nextInt(count);
    }
    final feature = rng.nextDouble() < d.colourShare
        ? OddFeature.colour
        : d.hidden[rng.nextInt(d.hidden.length)];

    final shape = feature == OddFeature.turn
        ? OddShape.triangle
        : OddShape.values[rng.nextInt(OddShape.values.length)];
    final turn = feature == OddFeature.turn ? rng.nextInt(4) : 0;
    OddTint tint() =>
        d.mixedTints && rng.nextBool() ? OddTint.blue : OddTint.ink;

    final tiles = <OddTile>[
      for (var i = 0; i < count; i++)
        OddTile(shape: shape, tint: tint(), turn: turn),
    ];
    if (d.mixedTints) {
      // Both everyday colours must show, or "mixed" means nothing.
      tiles[(odd + 1) % count] = OddTile(
        shape: shape,
        tint: OddTint.ink,
        turn: turn,
      );
      tiles[(odd + 2) % count] = OddTile(
        shape: shape,
        tint: OddTint.blue,
        turn: turn,
      );
    }

    final base = tiles[odd];
    tiles[odd] = switch (feature) {
      OddFeature.colour => OddTile(
        shape: shape,
        tint: OddTint.orange,
        turn: turn,
      ),
      OddFeature.shape => OddTile(
        shape: (OddShape.values.where((s) => s != shape).toList()..shuffle(rng))
            .first,
        tint: base.tint,
      ),
      OddFeature.turn => OddTile(
        shape: shape,
        tint: base.tint,
        turn: (turn + 1 + rng.nextInt(3)) % 4,
      ),
      OddFeature.size => OddTile(
        shape: shape,
        tint: base.tint,
        turn: turn,
        scale: d.smallScale,
      ),
    };
    return OddTrial(side: d.side, tiles: tiles, odd: odd, feature: feature);
  }
}
