import 'package:material_ui/material_ui.dart';

import '../lucid.dart';

/// Displays a small piece of maths written in a TeX-like shorthand:
///
/// | Write                   | Shows                         |
/// |-------------------------|-------------------------------|
/// | `x^2`, `e^{2x}`         | powers (raised, smaller)      |
/// | `a_1`, `x_{n+1}`        | subscripts                    |
/// | `\frac{1}{3}`           | a stacked fraction            |
/// | `\sqrt{x+1}`            | a square root with its bar    |
/// | `\int_{0}^{1}`          | an integral sign with limits  |
/// | `\sum_{k=1}^{n}`        | a sum sign with limits        |
/// | `\lim_{x \to 0}`        | "lim" with the limit below    |
/// | `\mat{1,2;3,4}`         | a matrix in square brackets   |
/// | `\det{1,2;3,4}`         | a determinant (straight bars) |
/// | `\pi \theta \lambda …`  | Greek letters                 |
/// | `\cdot \times \to \infty \le \ge \ne \approx \pm` | symbols |
/// | `\sin \cos \ln \exp`    | upright function names        |
///
/// Spaces in the source are kept as thin spaces; `*` shows as `·` and `-`
/// as a proper minus sign. Anything unknown is shown as written, so a typo
/// is visible rather than silently dropped.
class MathText extends StatelessWidget {
  const MathText(
    this.source, {
    super.key,
    this.size = 18,
    this.color,
    this.weight = 500,
  });

  final String source;
  final double size;
  final Color? color;
  final int weight;

  @override
  Widget build(BuildContext context) {
    final style = lucidText(
      size: size,
      weight: weight,
      color: color ?? DefaultTextStyle.of(context).style.color,
    );
    return Semantics(
      label: mathPlain(source),
      excludeSemantics: true,
      child: _render(parseMath(source), style),
    );
  }
}

/// [source] as plain, readable text ("1/3", "e^(2x)", "√(x+1)") for screen
/// readers, test finders and anywhere a widget won't fit.
String mathPlain(String source) => _plain(parseMath(source));

// ---- parse -----------------------------------------------------------------

/// A parsed piece of maths.
sealed class MathNode {
  const MathNode();
}

class MathRow extends MathNode {
  const MathRow(this.children);
  final List<MathNode> children;
}

class MathSym extends MathNode {
  const MathSym(this.text, {this.upright = false});
  final String text;

  /// Function names and digits; letters are otherwise the same font.
  final bool upright;
}

class MathFrac extends MathNode {
  const MathFrac(this.top, this.bottom);
  final MathNode top, bottom;
}

class MathScript extends MathNode {
  const MathScript(this.base, {this.sup, this.sub});
  final MathNode base;
  final MathNode? sup, sub;
}

class MathSqrt extends MathNode {
  const MathSqrt(this.body);
  final MathNode body;
}

/// ∫, ∑ or lim with its limits.
class MathBig extends MathNode {
  const MathBig(this.symbol, {this.lower, this.upper});
  final String symbol;
  final MathNode? lower, upper;
}

class MathMatrix extends MathNode {
  const MathMatrix(this.rows, {this.det = false});
  final List<List<MathNode>> rows;

  /// Straight bars (a determinant) rather than square brackets.
  final bool det;
}

const _symbols = {
  'pi': 'π',
  'theta': 'θ',
  'lambda': 'λ',
  'mu': 'μ',
  'sigma': 'σ',
  'rho': 'ρ',
  'alpha': 'α',
  'beta': 'β',
  'delta': 'δ',
  'Delta': 'Δ',
  'cdot': '·',
  'times': '×',
  'div': '÷',
  'to': '→',
  'infty': '∞',
  'le': '≤',
  'ge': '≥',
  'ne': '≠',
  'approx': '≈',
  'pm': '±',
};

const _functions = {'sin', 'cos', 'tan', 'ln', 'log', 'exp', 'det', 'tr'};

/// A typed space: a hair space, so operators (which carry their own
/// padding) never get doubled gaps.
const _space = '\u200A';

/// Parses the shorthand described on [MathText].
MathNode parseMath(String source) => _Parser(source).parseRow(null);

class _Parser {
  _Parser(this.s);

  final String s;
  int i = 0;

  bool get done => i >= s.length;
  String get ch => s[i];

  /// Reads nodes until [end] (a closing character) or the end.
  MathRow parseRow(String? end, {Set<String> stops = const {}}) {
    final out = <MathNode>[];
    while (!done) {
      if (end != null && ch == end) break;
      if (stops.contains(ch)) break;
      var node = _atom();
      if (node == null) continue;
      // Scripts attach to the atom just read.
      MathNode? sup, sub;
      while (!done && (ch == '^' || ch == '_')) {
        final up = ch == '^';
        i++;
        final arg = _argument();
        if (up) {
          sup = arg;
        } else {
          sub = arg;
        }
      }
      if (node is MathBig && (sup != null || sub != null)) {
        node = MathBig(node.symbol, lower: sub, upper: sup);
      } else if (sup != null || sub != null) {
        node = MathScript(node, sup: sup, sub: sub);
      }
      out.add(node);
    }
    return MathRow(out);
  }

  /// `{…}` or a single character.
  MathNode _argument() {
    if (done) return const MathRow([]);
    if (ch == '{') {
      i++;
      final row = parseRow('}');
      if (!done) i++;
      return row;
    }
    final a = _atom();
    return a ?? const MathRow([]);
  }

  String _word() {
    final start = i;
    while (!done && RegExp('[A-Za-z]').hasMatch(ch)) {
      i++;
    }
    return s.substring(start, i);
  }

  MathNode? _atom() {
    final c = ch;
    if (c == '\\') {
      i++;
      final name = _word();
      switch (name) {
        case 'frac':
          final top = _argument();
          final bottom = _argument();
          return MathFrac(top, bottom);
        case 'sqrt':
          return MathSqrt(_argument());
        case 'int':
          return const MathBig('∫');
        case 'sum':
          return const MathBig('∑');
        case 'lim':
          return const MathBig('lim');
        case 'mat':
        case 'det':
          if (!done && ch == '{') return _matrix(det: name == 'det');
          return MathSym(name, upright: true);
      }
      if (_symbols.containsKey(name)) return MathSym(_symbols[name]!);
      if (_functions.contains(name)) return MathSym(name, upright: true);
      return MathSym('\\$name');
    }
    i++;
    return switch (c) {
      '{' => () {
        final row = parseRow('}');
        if (!done) i++;
        return row;
      }(),
      ' ' => const MathSym(_space),
      '*' => const MathSym('·'),
      '-' => const MathSym('−'),
      _ => MathSym(c, upright: RegExp(r'[0-9.]').hasMatch(c)),
    };
  }

  /// `\mat{1,2;3,4}`: cells split by commas, rows by semicolons.
  MathNode _matrix({required bool det}) {
    i++; // {
    final rows = <List<MathNode>>[[]];
    while (!done && ch != '}') {
      final cell = parseRow(null, stops: const {',', ';', '}'});
      rows.last.add(cell);
      if (done) break;
      if (ch == ',') {
        i++;
      } else if (ch == ';') {
        i++;
        rows.add([]);
      }
    }
    if (!done) i++; // }
    return MathMatrix(rows, det: det);
  }
}

// ---- plain text --------------------------------------------------------------

String _plain(MathNode n) {
  String wrap(MathNode x) {
    final t = _plain(x);
    return t.length <= 1 ? t : '($t)';
  }

  return switch (n) {
    MathRow(:final children) => children.map(_plain).join(),
    MathSym(:final text) => text == _space ? ' ' : text,
    MathFrac(:final top, :final bottom) => '${wrap(top)}/${wrap(bottom)}',
    MathScript(:final base, :final sup, :final sub) =>
      '${_plain(base)}${sub == null ? '' : '_${wrap(sub)}'}'
          '${sup == null ? '' : '^${wrap(sup)}'}',
    MathSqrt(:final body) => '√${wrap(body)}',
    MathBig(:final symbol, :final lower, :final upper) =>
      '$symbol${lower == null ? '' : '_${wrap(lower)}'}'
          '${upper == null ? '' : '^${wrap(upper)}'} ',
    MathMatrix(:final rows, :final det) =>
      '${det ? 'det' : ''}[${rows.map((r) => r.map(_plain).join(', ')).join('; ')}]',
  };
}

// ---- render ------------------------------------------------------------------

Widget _render(MathNode n, TextStyle style) {
  final size = style.fontSize ?? 18;
  TextStyle scaled(double f) => style.copyWith(fontSize: size * f);

  switch (n) {
    case MathRow(:final children):
      if (children.length == 1) return _render(children.first, style);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [for (final c in children) _render(c, style)],
      );
    case MathSym(:final text):
      final padded = switch (text) {
        '=' ||
        '+' ||
        '−' ||
        '×' ||
        '÷' ||
        '≤' ||
        '≥' ||
        '≠' ||
        '≈' ||
        '→' => '\u2005$text\u2005',
        _ => text,
      };
      return Text(padded, style: style);
    case MathFrac(:final top, :final bottom):
      final small = scaled(0.82);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: size * 0.12),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _render(top, small)),
              Container(
                height: (size * 0.07).clamp(1.2, 2.5),
                margin: EdgeInsets.symmetric(vertical: size * 0.08),
                color: style.color,
              ),
              Center(child: _render(bottom, small)),
            ],
          ),
        ),
      );
    case MathScript(:final base, :final sup, :final sub):
      final small = scaled(0.62);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _render(base, style),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sup != null)
                _render(sup, small)
              else
                SizedBox(height: size * 0.5),
              SizedBox(height: size * (sub == null ? 0.45 : 0.1)),
              if (sub != null) _render(sub, small),
            ],
          ),
        ],
      );
    case MathSqrt(:final body):
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('√', style: scaled(1.1)),
          Container(
            padding: EdgeInsets.only(top: size * 0.08, right: size * 0.06),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: style.color ?? const Color(0xFF000000),
                  width: (size * 0.07).clamp(1.2, 2.5),
                ),
              ),
            ),
            child: _render(body, style),
          ),
        ],
      );
    case MathBig(:final symbol, :final lower, :final upper):
      final small = scaled(0.58);
      final isLim = symbol == 'lim';
      final sign = Text(
        symbol,
        style: isLim ? style : scaled(symbol == '∫' ? 1.55 : 1.3),
      );
      if (isLim) {
        return Padding(
          padding: EdgeInsets.only(right: size * 0.2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [sign, if (lower != null) _render(lower, small)],
          ),
        );
      }
      if (symbol == '∫') {
        // Limits sit to the right of the integral sign.
        return Padding(
          padding: EdgeInsets.only(right: size * 0.15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              sign,
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  upper == null
                      ? SizedBox(height: size * 0.6)
                      : _render(upper, small),
                  SizedBox(height: size * 0.5),
                  lower == null
                      ? SizedBox(height: size * 0.6)
                      : _render(lower, small),
                ],
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.only(right: size * 0.15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (upper != null) _render(upper, small),
            sign,
            if (lower != null) _render(lower, small),
          ],
        ),
      );
    case MathMatrix(:final rows, :final det):
      final cols = rows.fold(0, (m, r) => r.length > m ? r.length : m);
      final line = BorderSide(
        color: style.color ?? const Color(0xFF000000),
        width: (size * 0.08).clamp(1.5, 2.5),
      );
      Widget bracket(bool left) => Container(
        width: det ? 0 : size * 0.3,
        decoration: BoxDecoration(
          border: Border(
            left: left ? line : BorderSide.none,
            right: left ? BorderSide.none : line,
            top: det ? BorderSide.none : line,
            bottom: det ? BorderSide.none : line,
          ),
        ),
      );
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: size * 0.1),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bracket(true),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size * 0.35,
                  vertical: size * 0.15,
                ),
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    for (final r in rows)
                      TableRow(
                        children: [
                          for (var c = 0; c < cols; c++)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: size * 0.35,
                                vertical: size * 0.12,
                              ),
                              child: Center(
                                child: c < r.length
                                    ? _render(r[c], style)
                                    : const SizedBox(),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              bracket(false),
            ],
          ),
        ),
      );
  }
}
