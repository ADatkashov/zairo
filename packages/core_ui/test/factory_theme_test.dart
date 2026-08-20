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
}
