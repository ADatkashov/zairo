import 'dart:ui' show Color, FontWeight;
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Unbounded lacks Kazakh's extra Cyrillic letters and JetBrains Mono lacks
  // both those and the tenge sign — Golos Text must back them up or the glyphs
  // render in an arbitrary system font / a missing-glyph box.
  // testWidgets, not test(): building these styles touches google_fonts, which needs an initialized binding —
  // with a bare test() it logs "Binding has not yet been initialized" for every font (same as factory_theme_test).
  testWidgets('headline styles fall back to Golos Text for Kazakh letters', (tester) async {
    final textTheme = FactoryTypography.textTheme(const Color(0xFF000000));
    for (final style in [textTheme.displayLarge!, textTheme.headlineMedium!, textTheme.headlineSmall!]) {
      expect(style.fontFamilyFallback, isNotEmpty);
      expect(style.fontFamilyFallback!.single, startsWith('GolosText'));
    }
  });

  testWidgets('mono falls back to Golos Text so the tenge sign always has a glyph', (tester) async {
    final style = FactoryTypography.mono(weight: FontWeight.w700);
    expect(style.fontFamilyFallback!.single, startsWith('GolosText'));
  });
}
