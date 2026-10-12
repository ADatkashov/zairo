import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

Widget _app({String initial = '/', Locale locale = const Locale('en'), double textScale = 1}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    ],
  );
  return MaterialApp.router(
    theme: factoryLightTheme(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  );
}

/// Opens the welcome on top of Home, the way the first-launch gate does.
Future<void> _openOnTopOfHome(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.text('home'))).push('/welcome');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Next walks through the three pages and the last one offers Get started', (tester) async {
    await _openOnTopOfHome(tester, _app());

    expect(find.text('Every service nearby'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a time and book online'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('See what you pay up front'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    // Skip is hidden (but keeps its space) once there is nothing left to skip.
    expect(tester.widget<Visibility>(find.ancestor(of: find.text('Skip'), matching: find.byType(Visibility)).first).visible, isFalse);
  });

  testWidgets('Skip closes the welcome at once and returns to Home', (tester) async {
    await _openOnTopOfHome(tester, _app());

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('Every service nearby'), findsNothing);
  });

  testWidgets('Get started closes the welcome', (tester) async {
    await _openOnTopOfHome(tester, _app());
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('opened directly with nothing to go back to, Skip goes Home instead of failing', (tester) async {
    await tester.pumpWidget(_app(initial: '/welcome'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the illustrations are decorative and carry no semantics of their own', (tester) async {
    await _openOnTopOfHome(tester, _app());
    final handle = tester.ensureSemantics();

    // The headline and body are what a screen reader gets; the art is excluded.
    expect(find.bySemanticsLabel('Every service nearby'), findsOneWidget);
    expect(find.bySemanticsLabel('Beauty, auto and cleaning in one app.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^\d\d:\d\d')), findsNothing);
    handle.dispose();
  });

  for (final locale in ['en', 'ru', 'kk']) {
    testWidgets('fits a small phone with large text in $locale on every page', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);

      await _openOnTopOfHome(tester, _app(locale: Locale(locale), textScale: 1.5));
      for (var i = 0; i < 3; i++) {
        expect(tester.takeException(), isNull);
        if (i < 2) {
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
        }
      }
    });
  }
}
