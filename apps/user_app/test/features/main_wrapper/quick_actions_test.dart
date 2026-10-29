import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/booking/data/models/book_again_suggestion.dart';
import 'package:zairo/features/main_wrapper/presentation/quick_actions.dart';
import 'package:zairo/l10n/app_localizations.dart';

BookAgainSuggestion _visit() => BookAgainSuggestion(
  providerId: 'p-studio',
  providerName: 'Studio One',
  vertical: 'beauty',
  serviceId: 's-haircut',
  serviceTitle: 'Haircut',
  durationMinutes: 45,
  price: 6000,
  currency: 'KZT',
  lastVisitAt: DateTime(2026, 10, 1),
);

void main() {
  /// Builds the actions inside a real router and lists them as buttons that run their own onTap.
  Widget host(BookAgainSuggestion? visit) => MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) {
            final actions = quickActionsFor(context, AppLocalizations.of(context)!, visit);
            return Scaffold(
              body: Column(
                children: [for (final a in actions) TextButton(onPressed: a.onTap, child: Text(a.label))],
              ),
            );
          },
        ),
        GoRoute(path: '/search', builder: (_, state) => Scaffold(body: Text('Search ${state.uri.query}'))),
        GoRoute(
          path: '/provider/:id',
          builder: (_, state) => Scaffold(body: Text('Provider ${state.pathParameters['id']} ${state.uri.query}')),
        ),
      ],
    ),
  );

  testWidgets('always three: free today, find a service (the middle one, on top of the fan), and near me', (tester) async {
    await tester.pumpWidget(host(null));
    await tester.pumpAndSettle();

    final labels = [for (final t in tester.widgetList<Text>(find.byType(Text))) t.data];
    expect(labels, ['Free today', 'Find a service', 'Near me']);
    expect(find.text('Book again'), findsNothing);

    await tester.tap(find.text('Free today'));
    await tester.pumpAndSettle();
    expect(find.text('Search available=1'), findsOneWidget);
  });

  testWidgets('"Find a service" asks for the keyboard with a fresh request each time; "Near me" sorts by distance', (tester) async {
    await tester.pumpWidget(host(null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find a service'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Search focus='), findsOneWidget);

    GoRouter.of(tester.element(find.textContaining('Search focus='))).go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Near me'));
    await tester.pumpAndSettle();
    expect(find.text('Search sort=DISTANCE'), findsOneWidget);
  });

  testWidgets('with a past visit "Book again" takes the place of "Near me" and opens that service\'s booking steps', (tester) async {
    await tester.pumpWidget(host(_visit()));
    await tester.pumpAndSettle();

    expect([for (final t in tester.widgetList<Text>(find.byType(Text))) t.data], ['Free today', 'Find a service', 'Book again']);
    expect(find.text('Near me'), findsNothing);

    await tester.tap(find.text('Book again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Provider p-studio'), findsOneWidget);
    expect(find.textContaining('book=1'), findsOneWidget);
    expect(find.textContaining('service=s-haircut'), findsOneWidget);
  });
}
