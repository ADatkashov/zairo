import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// WCAG AA (4.5:1) for the colour pairs the apps actually put text on. Decorative
/// accents (coral, lavender, mint) are deliberately not here: they must not carry text.
void main() {
  for (final entry in {'light': FactoryColors.light, 'dark': FactoryColors.dark}.entries) {
    final c = entry.value;
    group('${entry.key} palette contrast', () {
      test('body text colours on every surface', () {
        for (final fg in [c.text, c.textSecondary, c.textTertiary]) {
          for (final bg in [c.bg, c.surface, c.surfaceAlt]) {
            expect(_ratio(fg, bg), greaterThanOrEqualTo(4.5));
          }
        }
      });
      test('error text (warnings, log out) on surfaces', () {
        for (final bg in [c.bg, c.surface, c.surfaceAlt]) {
          expect(_ratio(c.error, bg), greaterThanOrEqualTo(4.5));
        }
      });
      test('count badge: page background colour on the error colour', () {
        expect(_ratio(c.bg, c.error), greaterThanOrEqualTo(4.5));
      });
      test('label on the primary button', () {
        expect(_ratio(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
