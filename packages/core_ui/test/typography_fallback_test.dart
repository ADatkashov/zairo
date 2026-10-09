import 'dart:ui' show Color, FontWeight;
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Unbounded lacks Kazakh's extra Cyrillic letters and JetBrains Mono lacks
  // both those and the tenge sign — Golos Text must back them up or the glyphs
  // render in an arbitrary system font / a missing-glyph box.
  test('headline styles fall back to Golos Text for Kazakh letters', () {
    final textTheme = FactoryTypography.textTheme(const Color(0xFF000000));
    for (final style in [textTheme.displayLarge!, textTheme.headlineMedium!, textTheme.headlineSmall!]) {
      expect(style.fontFamilyFallback, isNotEmpty);
      expect(style.fontFamilyFallback!.single, startsWith('GolosText'));
    }
  });

  test('mono falls back to Golos Text so the tenge sign always has a glyph', () {
    final style = FactoryTypography.mono(weight: FontWeight.w700);
    expect(style.fontFamilyFallback!.single, startsWith('GolosText'));
  });
}
