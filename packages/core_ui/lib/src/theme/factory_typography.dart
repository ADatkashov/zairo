import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Three type roles, one system: Unbounded carries headline moments,
/// Golos Text carries every other piece of UI/body copy (chosen because it
/// was built natively for Cyrillic+Latin — this product ships in
/// Kazakh/Russian/English), and JetBrains Mono disciplines numbers —
/// prices, durations, times, distances — via [mono]/[price], which have no
/// equivalent role in Flutter's own [TextTheme].
class FactoryTypography {
  const FactoryTypography._();

  static TextStyle _display({required double size, required double height, FontWeight weight = FontWeight.w700}) {
    // Unbounded has none of Kazakh's extra Cyrillic letters (ә ғ қ ң ө ұ ү һ),
    // so every headline with one rendered it in an arbitrary system font or a
    // missing-glyph box. Golos Text covers them all and is already loaded for
    // body copy; it only ever supplies the glyphs Unbounded lacks.
    return GoogleFonts.unbounded(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      letterSpacing: -0.2,
    ).copyWith(fontFamilyFallback: [GoogleFonts.golosText(fontWeight: weight).fontFamily!]);
  }

  static TextStyle _body({
    required double size,
    required double height,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.golosText(fontSize: size, height: height / size, fontWeight: weight, letterSpacing: letterSpacing);
  }

  /// Tabular, monospaced — for prices, clock times, distances. Not part of
  /// Flutter's [TextTheme] roles, so reach for this directly:
  /// `Text('12 400 ₸', style: FactoryTypography.mono())`.
  static TextStyle mono({double size = 14, FontWeight weight = FontWeight.w600, Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
      // JetBrains Mono has no tenge sign (U+20B8) — the platform's main
      // currency — so without an explicit fallback "12 400 ₸" renders the
      // symbol in an arbitrary system font (or a missing-glyph box on
      // devices/web builds without one). Golos Text is already loaded for
      // all body copy and carries the glyph.
    ).copyWith(fontFamilyFallback: [GoogleFonts.golosText(fontWeight: weight).fontFamily!]);
  }

  static TextTheme textTheme(Color baseColor) {
    return TextTheme(
      displayLarge: _display(size: 32, height: 40).copyWith(color: baseColor),
      displayMedium: _display(size: 28, height: 36).copyWith(color: baseColor),
      displaySmall: _display(size: 24, height: 32).copyWith(color: baseColor),
      headlineLarge: _display(size: 24, height: 32).copyWith(color: baseColor),
      headlineMedium: _display(size: 22, height: 28, weight: FontWeight.w600).copyWith(color: baseColor),
      headlineSmall: _display(size: 20, height: 28, weight: FontWeight.w600).copyWith(color: baseColor),
      titleLarge: _body(size: 20, height: 28, weight: FontWeight.w700).copyWith(color: baseColor),
      titleMedium: _body(size: 17, height: 24, weight: FontWeight.w600).copyWith(color: baseColor),
      titleSmall: _body(size: 15, height: 20, weight: FontWeight.w600).copyWith(color: baseColor),
      bodyLarge: _body(size: 16, height: 24).copyWith(color: baseColor),
      bodyMedium: _body(size: 14, height: 20).copyWith(color: baseColor),
      bodySmall: _body(size: 12, height: 16).copyWith(color: baseColor),
      labelLarge: _body(size: 14, height: 20, weight: FontWeight.w600).copyWith(color: baseColor),
      labelMedium: _body(size: 13, height: 16, weight: FontWeight.w500, letterSpacing: 0.8).copyWith(color: baseColor),
      labelSmall: _body(size: 11, height: 14, weight: FontWeight.w500, letterSpacing: 0.6).copyWith(color: baseColor),
    );
  }
}
