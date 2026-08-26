import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Built inside testWidgets, not a bare test(): building the TextTheme
  // touches google_fonts, which needs a real Flutter binding to degrade
  // gracefully (falls back to the system font) when a test environment has
  // no network access to fetch the actual font files.
  testWidgets('light theme carries the Factory palette, not a Material seed default', (tester) async {
    final theme = factoryLightTheme();
    final colors = theme.extension<FactoryColors>();

    expect(colors, isNotNull);
    expect(colors!.primary, const Color(0xFF1B5C52));
    expect(theme.colorScheme.primary, const Color(0xFF1B5C52));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF7F6F3));
    expect(theme.brightness, Brightness.light);
  });

  testWidgets('dark theme is tuned, not an inversion of light', (tester) async {
    final theme = factoryDarkTheme();
    final colors = theme.extension<FactoryColors>();

    expect(colors, isNotNull);
    // Dark-mode primary is the brighter mint, not the same pine as light.
    expect(colors!.primary, const Color(0xFF4FCFB4));
    expect(colors.primary, isNot(FactoryColors.light.primary));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0F0E0C));
    expect(theme.brightness, Brightness.dark);
  });

  testWidgets('FactoryColors is reachable from BuildContext', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: Builder(
          builder: (context) {
            final primary = context.factoryColors.primary;
            return Text('primary:${primary.toARGB32()}');
          },
        ),
      ),
    );

    expect(find.text('primary:${const Color(0xFF1B5C52).toARGB32()}'), findsOneWidget);
  });

  test('light.warning is the WCAG-fixed shade, not the artifact\'s original 2.98:1 gold', () {
    // #B9862E (the design system artifact's literal value) reads 2.98:1 on
    // `bg` — below the 3:1 floor for large text/UI components, let alone
    // 4.5:1 for body text. #906824 (same hue/saturation, darker) reads
    // 4.64:1. Locks the fix in place against an accidental revert.
    expect(FactoryColors.light.warning, const Color(0xFF906824));
  });

  test('dark-mode elevation shadows are a light glow, not an invisible black-on-black shadow', () {
    final darkShadow = FactoryElevation.resolve(FactoryElevationLevel.lg, Brightness.dark).first;
    final lightShadow = FactoryElevation.resolve(FactoryElevationLevel.lg, Brightness.light).first;

    // A shadow tinted toward FactoryColors.dark.text (warm near-white)
    // is visible against the near-black dark bg; a black shadow at the
    // same alpha would blend into it instead.
    expect(darkShadow.color.r, greaterThan(lightShadow.color.r));
    expect(darkShadow.color.g, greaterThan(lightShadow.color.g));
    expect(darkShadow.color.b, greaterThan(lightShadow.color.b));
  });
}
