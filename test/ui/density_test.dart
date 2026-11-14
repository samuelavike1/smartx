import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartx/ui/density.dart';

void main() {
  test('compact on small phones, regular on the design frame', () {
    expect(Dims.isCompactSize(const Size(360, 640)), isTrue); // the CS50C
    expect(Dims.isCompactSize(const Size(390, 844)), isFalse); // artboards
    expect(Dims.isCompactSize(const Size(412, 915)), isFalse); // Pixel-class
    expect(Dims.isCompactSize(const Size(375, 667)), isTrue); // short iPhone SE
    expect(Dims.isCompactSize(const Size(360, 780)), isTrue); // narrow
  });

  test('touch targets stay at least 44 in compact', () {
    const c = Dims.compactDims;
    for (final size in [c.button, c.control, c.tray, c.spot]) {
      expect(size, greaterThanOrEqualTo(44));
    }
    expect(c.navHeight, greaterThanOrEqualTo(48));
  });
}
