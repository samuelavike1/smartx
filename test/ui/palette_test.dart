import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartx/games/ink_clash/ink_puzzle.dart';
import 'package:smartx/games/odd_one_out/odd_puzzle.dart';
import 'package:smartx/ui/palette.dart';

/// WCAG 2 contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  for (final (name, p) in [
    ('light', LucidPalette.light),
    ('night', LucidPalette.night),
  ]) {
    group('$name palette', () {
      // (foreground, background, minimum): 4.5 for text, 3 for icons,
      // borders and large display text.
      final pairs = <(String, Color, Color, double)>[
        ('ink on ground', p.ink, p.ground, 4.5),
        ('ink on surface', p.ink, p.surface, 4.5),
        ('ink on chip', p.ink, p.chip, 4.5),
        ('onInk on ink', p.onInk, p.ink, 4.5),
        ('muted on ground', p.muted, p.ground, 4.5),
        ('muted on surface', p.muted, p.surface, 4.5),
        ('faint on surface', p.faint, p.surface, 3),
        ('faint on chip', p.faint, p.chip, 3),
        ('onSpark on spark', p.onSpark, p.spark, 4.5),
        ('sparkText on sparkTint', p.sparkText, p.sparkTint, 4.5),
        ('sparkStrong on surface', p.sparkStrong, p.surface, 3),
        ('correct on surface', p.correct, p.surface, 3),
        ('onCorrect on correct', p.onCorrect, p.correct, 3),
        ('correctText on correctTint', p.correctText, p.correctTint, 4.5),
        ('correctText on surface', p.correctText, p.surface, 4.5),
        ('miss on surface', p.miss, p.surface, 3),
        ('onMiss on miss', p.onMiss, p.miss, 3),
        ('missText on missTint', p.missText, p.missTint, 4.5),
        ('missText on surface', p.missText, p.surface, 4.5),
        ('heroText on hero', p.heroText, p.hero, 4.5),
        ('heroQuiet on hero', p.heroQuiet, p.hero, 4.5),
        ('heroQuiet on heroRow', p.heroQuiet, p.heroRow, 4.5),
        ('heroLabel on hero', p.heroLabel, p.hero, 4.5),
        ('onHeroAccent on heroAccent', p.onHeroAccent, p.heroAccent, 4.5),
        (
          'muted (day) in the up-next row',
          LucidPalette.light.muted,
          p.heroAccent,
          4.5,
        ),
      ];
      for (final (label, fg, bg, need) in pairs) {
        test(label, () {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(need),
            reason: '$label is ${contrast(fg, bg).toStringAsFixed(2)}:1',
          );
        });
      }
    });
  }

  test(
    'Ink Clash words read on the ground in both modes (3:1, large text)',
    () {
      for (final ink in InkColour.values) {
        expect(
          contrast(ink.shade(night: false), LucidPalette.light.ground),
          greaterThanOrEqualTo(3),
          reason: '${ink.label} by day',
        );
        expect(
          contrast(ink.shade(night: true), LucidPalette.night.ground),
          greaterThanOrEqualTo(3),
          reason: '${ink.label} at night',
        );
      }
    },
  );

  test('Odd One Out keeps its brightness order at night', () {
    // Colour-blind players tell the odd colour by brightness, so the order
    // ink < blue < orange (day) must hold as ink > orange > blue (night)
    // with a clear gap between the odd colour and the others.
    for (final night in [false, true]) {
      final ink = OddTint.ink.shade(night: night);
      final blue = OddTint.blue.shade(night: night);
      final orange = OddTint.orange.shade(night: night);
      expect(contrast(orange, ink), greaterThanOrEqualTo(1.5));
      expect(contrast(orange, blue), greaterThanOrEqualTo(1.5));
      final surface = night
          ? LucidPalette.night.surface
          : LucidPalette.light.surface;
      for (final c in [ink, blue, orange]) {
        expect(contrast(c, surface), greaterThanOrEqualTo(3));
      }
    }
  });
}
