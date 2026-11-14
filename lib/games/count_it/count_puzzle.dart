import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';

int fact(int n) => n <= 1 ? 1 : n * fact(n - 1);

int perm(int n, int k) {
  var p = 1;
  for (var i = 0; i < k; i++) {
    p *= n - i;
  }
  return p;
}

int nCr(int n, int k) {
  if (k < 0 || k > n) return 0;
  return perm(n, k) ~/ fact(k);
}

int ipow(int b, int e) => e == 0 ? 1 : b * ipow(b, e - 1);

/// "10,000".
String fmt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '−' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// "5 × 4 × 3".
String chain(int from, int count) =>
    [for (var i = 0; i < count; i++) from - i].join(' × ');

enum CountKind {
  lineUp,
  jobs,
  handshakes,
  choose,
  codeRepeat,
  codeNoRepeat,
  subsets,
  tiles,
  grid,
  roundTable,
  atLeastOne,
  divisible,
  committee,
  share,
}

enum SceneType { people, tokens, tiles, code, grid, strip, sweets }

/// The picture above the question.
@immutable
class CountScene {
  const CountScene(
    this.type, {
    this.labels = const [],
    this.marked = const {},
    this.a = 0,
    this.b = 0,
    required this.caption,
  });

  final SceneType type;

  /// People's initials, token numbers, tile letters or code alphabet.
  final List<String> labels;

  /// Labels drawn filled (the juniors in a committee).
  final Set<int> marked;

  /// Grid width / code length / strip end / sweets.
  final int a;

  /// Grid height / children.
  final int b;
  final String caption;
}

/// A wrong answer and the mistake that leads to it.
@immutable
class Trap {
  const Trap(this.value, this.why);

  final int value;
  final String why;
}

@immutable
class CountQuestion {
  const CountQuestion({
    required this.level,
    required this.seed,
    required this.kind,
    required this.params,
    required this.scene,
    required this.question,
    required this.answer,
    required this.traps,
    required this.steps,
    required this.insight,
    required this.options,
    this.counts = const [],
  });

  final int level;
  final int seed;
  final CountKind kind;

  /// The numbers that define the question, for recounting in tests.
  final Map<String, int> params;

  /// Tiles: how many of each letter.
  final List<int> counts;
  final CountScene scene;
  final String question;
  final int answer;
  final List<Trap> traps;
  final List<String> steps;
  final String insight;
  final List<int> options;

  int get answerIndex => options.indexOf(answer);

  String feedbackFor(int picked) {
    if (picked == answer) return insight;
    final t = traps.where((t) => t.value == picked).firstOrNull;
    return t?.why ?? 'Count it again in steps: see the working.';
  }
}

class CountDifficulty {
  static List<CountKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [CountKind.lineUp, CountKind.codeRepeat],
    2 => const [CountKind.jobs, CountKind.handshakes],
    3 => const [CountKind.choose, CountKind.codeNoRepeat],
    4 => const [CountKind.subsets, CountKind.lineUp, CountKind.jobs],
    5 => const [CountKind.tiles],
    6 => const [CountKind.grid],
    7 => const [CountKind.roundTable, CountKind.atLeastOne],
    8 => const [CountKind.divisible],
    9 => const [CountKind.committee, CountKind.share],
    _ => const [
      CountKind.tiles,
      CountKind.grid,
      CountKind.atLeastOne,
      CountKind.divisible,
      CountKind.committee,
      CountKind.share,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'lining up and codes',
    2 => 'jobs and handshakes',
    3 => 'groups where order doesn\'t matter',
    4 => 'subsets and longer lines',
    5 => 'rows of tiles with repeats',
    6 => 'routes on a grid',
    7 => 'round tables and "at least one"',
    8 => 'this or that, minus the overlap',
    9 => 'committees and sharing sweets',
    _ => 'the hard ones, bigger',
  };
}

class CountGenerator {
  const CountGenerator();

  static const _letters = 'ABCDEFGHIJKL';

  CountQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = CountDifficulty.kindsFor(level);
    final kind = kinds[rng.nextInt(kinds.length)];
    final big = level >= 10;
    int pick(int lo, int hi) => lo + rng.nextInt(hi - lo + 1);
    List<String> people(int n) => [for (var i = 0; i < n; i++) _letters[i]];

    late final Map<String, int> params;
    var counts = const <int>[];
    late final CountScene scene;
    late final String question;
    late final int answer;
    late final List<Trap> traps;
    late final List<String> steps;
    late final String insight;

    switch (kind) {
      case CountKind.lineUp:
        final n = level >= 4 ? pick(5, 6) : pick(4, 5);
        params = {'n': n};
        scene = CountScene(
          SceneType.people,
          labels: people(n),
          caption: '$n friends',
        );
        question = 'In how many orders can these $n friends stand in a line?';
        answer = fact(n);
        traps = [
          Trap(
            n * n,
            '${fmt(n * n)} lets one friend take two spots. Each spot has one '
            'fewer choice than the last.',
          ),
          Trap(
            n * (n + 1) ~/ 2,
            '${fmt(n * (n + 1) ~/ 2)} adds the choices. Spots are filled one '
            'after another, so multiply them.',
          ),
          Trap(
            fact(n - 1),
            '${fmt(fact(n - 1))} is a round table, where turning doesn\'t '
            'count. In a line the ends are different.',
          ),
          Trap(
            ipow(n, n),
            '${fmt(ipow(n, n))} lets every spot pick from all $n friends.',
          ),
          Trap(
            fact(n + 1),
            '${fmt(fact(n + 1))} lines up ${n + 1} friends, one too many.',
          ),
        ];
        steps = [
          'First spot: $n choices. Then ${n - 1}, then ${n - 2}, and so on.',
          '${chain(n, n)} = ${fmt(fact(n))}.',
          'So $n friends can line up ${fmt(fact(n))} ways.',
        ];
        insight =
            'Filling spots one after another means multiplying: '
            '${chain(n, n)}.';

      case CountKind.jobs:
        final n = pick(5, 9);
        final k = level >= 4 ? 3 : 2;
        params = {'n': n, 'k': k};
        final roles = k == 2
            ? 'a captain and a deputy'
            : 'a captain, a deputy and a treasurer';
        scene = CountScene(
          SceneType.people,
          labels: people(n),
          caption: 'A club of $n',
        );
        question =
            'The club picks $roles. Nobody holds two jobs. How many ways?';
        answer = perm(n, k);
        traps = [
          Trap(
            nCr(n, k),
            '${fmt(nCr(n, k))} treats the jobs as the same. Captain A with '
            'deputy B is different from captain B with deputy A.',
          ),
          Trap(ipow(n, k), '${fmt(ipow(n, k))} lets one person hold two jobs.'),
          Trap(
            n * k,
            '${fmt(n * k)} adds up the choices for each job. Multiply them.',
          ),
          Trap(perm(n, k - 1), '${fmt(perm(n, k - 1))} fills one job too few.'),
        ];
        steps = [
          'Captain: $n choices. Deputy: ${n - 1} left.'
              '${k == 3 ? ' Treasurer: ${n - 2} left.' : ''}',
          '${chain(n, k)} = ${fmt(answer)}.',
          'The jobs differ, so order matters: ${fmt(answer)} ways.',
        ];
        insight = 'Different jobs means order matters: ${chain(n, k)}.';

      case CountKind.handshakes:
        final n = pick(5, level >= 4 ? 12 : 9);
        params = {'n': n};
        scene = CountScene(
          SceneType.people,
          labels: people(n),
          caption: '$n people',
        );
        question =
            'Each pair of these $n people shakes hands once. How many '
            'handshakes?';
        answer = nCr(n, 2);
        traps = [
          Trap(
            n * (n - 1),
            '${fmt(n * (n - 1))} counts each handshake twice: A with B is the '
            'same handshake as B with A.',
          ),
          Trap(
            n * n,
            '${fmt(n * n)} has people shake their own hands, and counts each '
            'pair twice.',
          ),
          Trap(n - 1, '${n - 1} is one person\'s handshakes, not everyone\'s.'),
          Trap(nCr(n, 3), '${fmt(nCr(n, 3))} counts groups of three.'),
        ];
        steps = [
          'Each person shakes ${n - 1} hands: $n × ${n - 1} = '
              '${fmt(n * (n - 1))}.',
          'That counts every handshake twice, once from each side.',
          '${fmt(n * (n - 1))} ÷ 2 = ${fmt(answer)}.',
        ];
        insight = 'Pairs don\'t have an order: $n × ${n - 1} ÷ 2.';

      case CountKind.choose:
        final n = pick(6, 10);
        final k = pick(2, 4);
        params = {'n': n, 'k': k};
        scene = CountScene(
          SceneType.tokens,
          labels: [for (var i = 1; i <= n; i++) '$i'],
          caption: '$n toppings',
        );
        question =
            'You pick $k different toppings out of $n. How many choices?';
        answer = nCr(n, k);
        traps = [
          Trap(
            perm(n, k),
            '${fmt(perm(n, k))} counts the same toppings in a different order '
            'as new. A pizza doesn\'t care about order.',
          ),
          Trap(ipow(n, k), '${fmt(ipow(n, k))} lets you pick a topping twice.'),
          Trap(n * k, '${fmt(n * k)} adds choices instead of counting groups.'),
          Trap(
            nCr(n, k - 1),
            '${fmt(nCr(n, k - 1))} picks one topping too few.',
          ),
        ];
        steps = [
          'In order: ${chain(n, k)} = ${fmt(perm(n, k))}.',
          'Each group of $k shows up ${chain(k, k)} = ${fact(k)} times in '
              'that count.',
          '${fmt(perm(n, k))} ÷ ${fact(k)} = ${fmt(answer)}.',
        ];
        insight =
            'Order doesn\'t matter, so divide the ordered count by $k!: '
            '${fmt(answer)}.';

      case CountKind.codeRepeat:
      case CountKind.codeNoRepeat:
        final repeat = kind == CountKind.codeRepeat;
        final (a, from) = [(10, 0), (6, 1), (5, 1)][rng.nextInt(3)];
        final len = level >= 3 ? pick(3, 4) : 3;
        params = {'a': a, 'len': len};
        final range = '$from to ${from + a - 1}';
        scene = CountScene(
          SceneType.code,
          labels: [for (var i = 0; i < a; i++) '${from + i}'],
          a: len,
          caption: 'Digits $range',
        );
        question = repeat
            ? 'A lock code has $len digits from $range. Digits can repeat. '
                  'How many codes?'
            : 'A lock code has $len digits from $range. No digit repeats. '
                  'How many codes?';
        answer = repeat ? ipow(a, len) : perm(a, len);
        traps = [
          repeat
              ? Trap(
                  perm(a, len),
                  '${fmt(perm(a, len))} forbids repeats, but a code like '
                  '${from + 1}-${from + 1}-$from is fine here.',
                )
              : Trap(
                  ipow(a, len),
                  '${fmt(ipow(a, len))} allows repeats, which this lock '
                  'doesn\'t.',
                ),
          Trap(
            nCr(a, len),
            '${fmt(nCr(a, len))} ignores order, but ${from + 1}-${from + 2}-'
            '${from + 3} and ${from + 3}-${from + 2}-${from + 1} are different '
            'codes.',
          ),
          Trap(
            a * len,
            '${fmt(a * len)} adds the choices for each digit. Multiply them.',
          ),
          Trap(
            repeat ? ipow(a, len - 1) : perm(a, len - 1),
            'That counts one digit too few.',
          ),
          Trap(
            ipow(len, a),
            '${fmt(ipow(len, a))} swaps them round: it\'s $a choices for each '
            'of $len digits, not $len choices for each of $a.',
          ),
          Trap(
            repeat ? ipow(a, len + 1) : perm(a, len + 1),
            'That counts one digit too many.',
          ),
        ];
        steps = repeat
            ? [
                'Each of the $len digits has $a choices.',
                '${List.filled(len, a).join(' × ')} = ${fmt(answer)}.',
                'Repeats are allowed, so the choices never shrink.',
              ]
            : [
                'First digit: $a choices, then ${a - 1} left, and so on.',
                '${chain(a, len)} = ${fmt(answer)}.',
                'No repeats, so each digit has one choice fewer.',
              ];
        insight = repeat
            ? 'With repeats every digit has $a choices: $a to the power '
                  '$len.'
            : 'Without repeats the choices shrink: ${chain(a, len)}.';

      case CountKind.subsets:
        final n = pick(4, 7);
        params = {'n': n};
        scene = CountScene(
          SceneType.tokens,
          labels: [for (var i = 1; i <= n; i++) '$i'],
          caption: '$n different books',
        );
        question =
            'You may take any of these $n books, or none. How many '
            'different selections?';
        answer = ipow(2, n);
        traps = [
          Trap(
            ipow(2, n) - 1,
            '${fmt(ipow(2, n) - 1)} leaves out taking none, which counts '
            'here.',
          ),
          Trap(n * n, '${fmt(n * n)} isn\'t a count of selections.'),
          Trap(
            fact(n),
            '${fmt(fact(n))} counts orders, but a selection has no order.',
          ),
          Trap(
            2 * n,
            '${fmt(2 * n)} adds the two choices per book. Multiply them.',
          ),
        ];
        steps = [
          'Each book is taken or left: 2 choices.',
          '${List.filled(n, 2).join(' × ')} = ${fmt(answer)}.',
          'That includes taking none and taking all.',
        ];
        insight = 'Each item is in or out: 2 to the power $n.';

      case CountKind.tiles:
        final shapes = big
            ? const [
                [2, 2, 2],
                [3, 2, 1],
                [2, 2, 1, 1],
                [3, 3],
              ]
            : const [
                [2, 1, 1],
                [2, 2],
                [2, 2, 1],
                [3, 1, 1],
                [3, 2],
                [2, 1, 1, 1],
              ];
        counts = shapes[rng.nextInt(shapes.length)];
        final n = counts.fold(0, (s, c) => s + c);
        params = {'n': n};
        final tiles = [
          for (final (i, c) in counts.indexed)
            for (var j = 0; j < c; j++) _letters[i],
        ];
        scene = CountScene(SceneType.tiles, labels: tiles, caption: '$n tiles');
        question = 'How many different rows can these $n tiles make?';
        final over = counts.fold(1, (p, c) => p * fact(c));
        answer = fact(n) ~/ over;
        final repeats = [
          for (final (i, c) in counts.indexed)
            if (c > 1) (_letters[i], c),
        ];
        const words = {2: 'two', 3: 'three'};
        final names = repeats
            .map((r) => 'the ${words[r.$2]} ${r.$1}\'s')
            .join(', or ');
        final verb = repeats.any((r) => r.$2 > 2) ? 'Reordering' : 'Swapping';
        final factors = repeats.map((r) => fact(r.$2)).join(' × ');
        traps = [
          Trap(
            fact(n),
            '${fmt(fact(n))} treats matching tiles as different. Swapping two '
            '${repeats.first.$1}\'s doesn\'t make a new row.',
          ),
          if (repeats.length > 1)
            Trap(
              fact(n) ~/ fact(repeats.first.$2),
              '${fmt(fact(n) ~/ fact(repeats.first.$2))} allows for the '
              'repeated ${repeats.first.$1}\'s but not the other repeats.',
            ),
          Trap(
            fact(n) ~/ (over * 2),
            'That divides by too much: only matching tiles swap for free.',
          ),
          Trap(
            fact(counts.length),
            '${fmt(fact(counts.length))} only orders the different letters, '
            'not all $n tiles.',
          ),
          Trap(
            fact(n) ~/ 2,
            '${fmt(fact(n) ~/ 2)} divides by 2 once, but each set of '
            'matching tiles needs its own share.',
          ),
        ];
        steps = [
          'If all $n tiles were different: ${chain(n, n)} = ${fmt(fact(n))} '
              'rows.',
          '$verb $names${repeats.length > 1 ? ',' : ''} gives the same row: each row was counted '
              '${repeats.length > 1 ? '$factors = ' : ''}${fmt(over)} times.',
          '${fmt(fact(n))} ÷ ${fmt(over)} = ${fmt(answer)} different rows.',
        ];
        insight =
            'Count as if all were different, then divide out the swaps of '
            'matching tiles.';

      case CountKind.grid:
        final w = big ? pick(4, 5) : pick(2, 4);
        final h = big ? pick(3, 4) : pick(2, 3);
        params = {'w': w, 'h': h};
        scene = CountScene(
          SceneType.grid,
          a: w,
          b: h,
          caption: '$w blocks across, $h up',
        );
        question = 'Moving only right or up, how many routes go from A to B?';
        answer = nCr(w + h, h);
        traps = [
          Trap(w * h, '${fmt(w * h)} counts the blocks, not the routes.'),
          Trap(
            ipow(2, w + h),
            '${fmt(ipow(2, w + h))} lets every move go either way, but a '
            'route needs exactly $w rights and $h ups.',
          ),
          Trap(
            fact(w + h),
            '${fmt(fact(w + h))} treats every move as different, but the '
            '$w rights are alike, and so are the $h ups.',
          ),
          Trap(w + h, '${w + h} is the length of one route.'),
        ];
        steps = [
          'Every route is ${w + h} moves: $w rights and $h ups.',
          'A route is fixed by which $h of the ${w + h} moves go up.',
          'Choose $h of ${w + h}: ${fmt(answer)} routes.',
        ];
        insight =
            'A route is just a choice of which moves go up: choose $h of '
            '${w + h}.';

      case CountKind.roundTable:
        final n = pick(4, 7);
        params = {'n': n};
        scene = CountScene(
          SceneType.people,
          labels: people(n),
          caption: '$n friends, a round table',
        );
        question =
            'These $n friends sit at a round table. Turning everyone round '
            'together gives the same seating. How many seatings?';
        answer = fact(n - 1);
        traps = [
          Trap(
            fact(n),
            '${fmt(fact(n))} counts turning the table as a new seating.',
          ),
          if (fact(n - 1).isEven)
            Trap(
              fact(n - 1) ~/ 2,
              '${fmt(fact(n - 1) ~/ 2)} also counts mirror images as the '
              'same, but clockwise and anticlockwise differ here.',
            ),
          Trap(n * n, '${fmt(n * n)} isn\'t a count of orders.'),
          Trap(
            fact(n - 2),
            '${fmt(fact(n - 2))} fixes two friends, but only one is free to '
            'fix.',
          ),
        ];
        steps = [
          'Turning makes every seat alike, so seat A anywhere.',
          'The other ${n - 1} fill the seats round from A: '
              '${chain(n - 1, n - 1)}.',
          'That\'s ${fmt(answer)} seatings.',
        ];
        insight = 'Fix one person, then order the rest: (${n - 1})!.';

      case CountKind.atLeastOne:
        final a = pick(4, 6);
        final len = big ? 4 : 3;
        params = {'a': a, 'len': len};
        final last = _letters[a - 1];
        scene = CountScene(
          SceneType.code,
          labels: [for (var i = 0; i < a; i++) _letters[i]],
          a: len,
          caption: 'Letters A to $last',
        );
        question =
            'Codes of $len letters from A to $last, repeats allowed. How '
            'many have at least one A?';
        final all = ipow(a, len), none = ipow(a - 1, len);
        answer = all - none;
        traps = [
          Trap(none, '${fmt(none)} is the codes with no A at all.'),
          Trap(
            len * ipow(a, len - 1),
            '${fmt(len * ipow(a, len - 1))} counts a code with two A\'s more '
            'than once.',
          ),
          Trap(all, '${fmt(all)} is every code, with an A or not.'),
          Trap(
            len * ipow(a - 1, len - 1),
            '${fmt(len * ipow(a - 1, len - 1))} counts codes with exactly '
            'one A.',
          ),
        ];
        steps = [
          'All codes: ${List.filled(len, a).join(' × ')} = ${fmt(all)}.',
          'Codes with no A: ${List.filled(len, a - 1).join(' × ')} = '
              '${fmt(none)}.',
          '${fmt(all)} − ${fmt(none)} = ${fmt(answer)}.',
        ];
        insight = '"At least one" is easiest as all, minus none.';

      case CountKind.divisible:
        final (p, q, l) = [
          (2, 3, 6),
          (2, 5, 10),
          (3, 5, 15),
          (4, 6, 12),
        ][rng.nextInt(4)];
        final n = pick(big ? 60 : 24, big ? 120 : 60);
        params = {'n': n, 'p': p, 'q': q, 'l': l};
        scene = CountScene(SceneType.strip, a: n, caption: '1 to $n');
        question =
            'How many whole numbers from 1 to $n divide by $p or by $q '
            '(or both)?';
        final x = n ~/ p, y = n ~/ q, z = n ~/ l;
        answer = x + y - z;
        traps = [
          Trap(
            x + y,
            '${fmt(x + y)} counts numbers like $l twice: they divide by both.',
          ),
          Trap(z, '${fmt(z)} is the numbers that divide by both.'),
          Trap(
            n - answer,
            '${fmt(n - answer)} is the numbers that divide by '
            'neither.',
          ),
          Trap(
            x + y - 2 * z,
            '${fmt(x + y - 2 * z)} takes the overlap off twice: it was only '
            'counted twice, so take it off once.',
          ),
        ];
        steps = [
          'Multiples of $p up to $n: $x. Multiples of $q: $y.',
          'Both means divide by $l: $z, and those were counted twice.',
          '$x + $y − $z = ${fmt(answer)}.',
        ];
        insight = 'Add both counts, then take off the overlap once.';

      case CountKind.committee:
        final m = pick(4, 6);
        final w = pick(3, 5);
        params = {'m': m, 'w': w};
        scene = CountScene(
          SceneType.people,
          labels: people(m + w),
          marked: {for (var i = m; i < m + w; i++) i},
          caption: '$m seniors, $w juniors (filled)',
        );
        question =
            'A team of 3 is picked from these $m seniors and $w juniors. It '
            'needs at least one junior. How many teams?';
        final all = nCr(m + w, 3), none = nCr(m, 3);
        answer = all - none;
        traps = [
          Trap(
            w * nCr(m + w - 1, 2),
            '${fmt(w * nCr(m + w - 1, 2))} picks "the junior" first, so a '
            'team with two juniors is counted more than once.',
          ),
          Trap(all, '${fmt(all)} allows teams with no junior.'),
          Trap(
            w * nCr(m, 2),
            '${fmt(w * nCr(m, 2))} is the teams with exactly one junior.',
          ),
          Trap(none, '${fmt(none)} is the teams with no junior.'),
        ];
        steps = [
          'Any 3 of ${m + w}: ${fmt(all)} teams.',
          'Teams with no junior, all 3 from $m seniors: ${fmt(none)}.',
          '${fmt(all)} − ${fmt(none)} = ${fmt(answer)}.',
        ];
        insight = '"At least one" is all teams minus the teams with none.';

      case CountKind.share:
        final s = pick(4, big ? 9 : 7);
        final c = pick(2, big ? 4 : 3);
        params = {'s': s, 'c': c};
        scene = CountScene(
          SceneType.sweets,
          labels: people(c),
          a: s,
          b: c,
          caption: '$s sweets, $c children',
        );
        question =
            'These $s identical sweets are shared among $c children. A child '
            'may get none. How many ways?';
        answer = nCr(s + c - 1, c - 1);
        traps = [
          Trap(
            ipow(c, s),
            '${fmt(ipow(c, s))} treats the sweets as different, but they\'re '
            'identical.',
          ),
          Trap(
            nCr(s - 1, c - 1),
            '${fmt(nCr(s - 1, c - 1))} gives every child at least one.',
          ),
          Trap(s * c, '${fmt(s * c)} isn\'t a count of sharings.'),
          Trap(
            nCr(s + c, c),
            '${fmt(nCr(s + c, c))} uses one divider too many.',
          ),
        ];
        steps = [
          'Line up the $s sweets with ${c - 1} '
              '${c == 2 ? 'divider' : 'dividers'} between children: '
              '${s + c - 1} places.',
          'A sharing is fixed by where the ${c - 1} '
              '${c == 2 ? 'divider goes' : 'dividers go'}.',
          'Choose ${c - 1} of ${s + c - 1}: ${fmt(answer)} ways.',
        ];
        insight = 'Sweets and dividers in a row: choose where the dividers go.';
    }

    // Three wrong answers, smallest to largest with the answer among them
    // at a random rank: named traps first, so the biggest (or smallest)
    // number is never a giveaway. Rarely a side runs short of traps; then
    // plain near misses fill in.
    const again = 'Count it again in steps: see the working.';
    final fillers = [
      Trap(
        answer * 2,
        '${fmt(answer * 2)} counts every case twice, once from each way '
        'round.',
      ),
      if (answer.isEven)
        Trap(answer ~/ 2, '${fmt(answer ~/ 2)} counts only half the cases.'),
      Trap(answer + 1, '${fmt(answer + 1)} is one too many: an off-by-one.'),
      Trap(answer - 1, '${fmt(answer - 1)} is one short: an off-by-one.'),
      for (var d = 2; d <= 3; d++) ...[
        Trap(answer + d, again),
        Trap(answer - d, again),
      ],
    ];
    final chosen = balancedOptions(
      Trap(answer, ''),
      traps.where((t) => t.value > 0),
      fillers.where((t) => t.value > 0),
      rng,
      compare: (a, b) => a.value.compareTo(b.value),
    );
    final picked = [
      for (final t in chosen)
        if (t.value != answer) t,
    ];
    final options = [for (final t in chosen) t.value];

    return CountQuestion(
      level: level,
      seed: seed,
      kind: kind,
      params: params,
      counts: counts,
      scene: scene,
      question: question,
      answer: answer,
      traps: picked,
      steps: steps,
      insight: insight,
      options: options,
    );
  }
}
