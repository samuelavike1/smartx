import 'package:flutter/foundation.dart';

/// An exact fraction, always in lowest terms with a positive denominator.
/// Odds On works in these so no answer is ever rounded.
@immutable
class Frac implements Comparable<Frac> {
  factory Frac(int n, [int d = 1]) {
    if (d == 0) throw ArgumentError('zero denominator');
    if (d < 0) {
      n = -n;
      d = -d;
    }
    final g = _gcd(n.abs(), d);
    return Frac._(n ~/ (g == 0 ? 1 : g), d ~/ (g == 0 ? 1 : g));
  }

  const Frac._(this.n, this.d);

  static const zero = Frac._(0, 1);
  static const one = Frac._(1, 1);

  final int n;
  final int d;

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  Frac operator +(Frac o) => Frac(n * o.d + o.n * d, d * o.d);
  Frac operator -(Frac o) => Frac(n * o.d - o.n * d, d * o.d);
  Frac operator *(Frac o) => Frac(n * o.n, d * o.d);
  Frac operator /(Frac o) => Frac(n * o.d, d * o.n);

  /// Raised to a whole power.
  Frac pow(int k) {
    var r = one;
    for (var i = 0; i < k; i++) {
      r = r * this;
    }
    return r;
  }

  double get value => n / d;

  /// A probability strictly between 0 and 1, or exactly 1.
  bool get isProbability => n > 0 && n <= d;

  /// "about 14%", "under 1%".
  String get percent {
    final p = value * 100;
    if (p > 0 && p < 1) return 'under 1%';
    return 'about ${p.round()}%';
  }

  /// The bare percentage, "14%".
  String get shortPercent {
    final p = value * 100;
    if (p > 0 && p < 1) return '<1%';
    return '${p.round()}%';
  }

  @override
  int compareTo(Frac o) => (n * o.d).compareTo(o.n * d);

  bool operator <(Frac o) => compareTo(o) < 0;
  bool operator >(Frac o) => compareTo(o) > 0;
  bool operator <=(Frac o) => compareTo(o) <= 0;
  bool operator >=(Frac o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Frac && other.n == n && other.d == d;

  @override
  int get hashCode => Object.hash(n, d);

  @override
  String toString() => d == 1 ? '$n' : '$n/$d';
}

/// n choose k.
int choose(int n, int k) {
  if (k < 0 || k > n) return 0;
  var r = 1;
  for (var i = 0; i < k; i++) {
    r = r * (n - i) ~/ (i + 1);
  }
  return r;
}
