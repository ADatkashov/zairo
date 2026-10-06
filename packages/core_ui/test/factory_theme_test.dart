import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _contrastTests();
  _profileAndTrendTests();
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

void _profileAndTrendTests() {
  testWidgets('app profile is opt-in and carries per-app card radius', (tester) async {
    expect(factoryLightTheme().extension<FactoryAppProfile>(), isNull);
    final p = factoryLightTheme(profile: FactoryAppProfile.platform).extension<FactoryAppProfile>();
    expect(p!.cardRadius, 12);
    expect(FactoryAppProfile.consumer.cardRadius, 24);
  });

  testWidgets('FactoryTrendBadge shows arrow and sign', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: factoryLightTheme(),
      home: const Column(children: [
        FactoryTrendBadge(delta: 12),
        FactoryTrendBadge(delta: -4),
      ]),
    ));
    expect(find.text('▲ +12%'), findsOneWidget);
    expect(find.text('▼ −4%'), findsOneWidget);
  });

  testWidgets('FactoryPaymentBreakdown shows remaining = total - deposit', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: factoryLightTheme(),
      home: const Scaffold(
        body: FactoryPaymentBreakdown(
          total: 8500,
          deposit: 2550,
          currency: 'KZT',
          totalLabel: 'Total',
          depositLabel: 'Deposit',
          remainingLabel: 'Pay later',
        ),
      ),
    ));
    expect(find.textContaining('5 950'), findsOneWidget);
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void _contrastTests() {
  // Guards the AA fixes: body-size text roles must stay >= 4.5:1 on the
  // surfaces they are drawn on, in both themes.
  for (final entry in {'light': FactoryColors.light, 'dark': FactoryColors.dark}.entries) {
    final c = entry.value;
    test('${entry.key}: text roles clear 4.5:1 on bg and surface', () {
      for (final bg in [c.bg, c.surface]) {
        expect(_contrast(c.text, bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.textSecondary, bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.textTertiary, bg), greaterThanOrEqualTo(4.5));
      }
    });
    test('${entry.key}: onPrimary on primary and primaryStrong', () {
      expect(_contrast(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.onPrimary, c.primaryStrong), greaterThanOrEqualTo(4.5));
    });
    test('${entry.key}: state colors read on surface', () {
      for (final tone in [c.success, c.warning, c.error, c.info]) {
        expect(_contrast(tone, c.surface), greaterThanOrEqualTo(4.5));
      }
    });
  }
}
