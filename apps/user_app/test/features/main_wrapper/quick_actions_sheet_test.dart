import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/models/book_again_suggestion.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/main_wrapper/presentation/widgets/quick_actions_sheet.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _LoggedIn extends AuthController {
  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'user-1', email: 'a@example.com', displayName: 'Aigerim', role: 'CUSTOMER');
}

class _BookingApi extends BookingApi {
  _BookingApi(this._suggestions, {this.fails = false}) : super(DioClient(Dio()));

  final List<BookAgainSuggestion> _suggestions;
  final bool fails;

  @override
  Future<List<BookAgainSuggestion>> listBookAgainSuggestions(String userId) async {
    if (fails) throw Exception('offline');
    return _suggestions;
  }
}

BookAgainSuggestion _visit(String service, String business) => BookAgainSuggestion(
  providerId: 'p-$business',
  providerName: business,
  vertical: 'beauty',
  serviceId: 's-$service',
  serviceTitle: service,
  durationMinutes: 45,
  price: 6000,
  currency: 'KZT',
  lastVisitAt: DateTime(2026, 10, 1),
);

void main() {
  /// Home page with a "+" button; the router records where the quick actions went.
  Widget host({List<BookAgainSuggestion>? history, bool failing = false, Object? onProviderExtra}) {
    return ProviderScope(
      overrides: [
        if (history != null) authControllerProvider.overrideWith(_LoggedIn.new),
        bookingApiProvider.overrideWithValue(_BookingApi(history ?? const [], fails: failing)),
      ],
      child: MaterialApp.router(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: Center(child: TextButton(onPressed: () => showQuickActionsSheet(context), child: const Text('plus'))),
              ),
            ),
            GoRoute(path: '/search', builder: (_, state) => Scaffold(body: Text('Search ${state.uri.query}'))),
            GoRoute(
              path: '/provider/:id',
              builder: (_, state) => Scaffold(body: Text('Provider ${state.pathParameters['id']} ${state.uri.query}')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text('plus'));
    await tester.pumpAndSettle();
  }

  testWidgets('a guest gets three actions, each one tap from the right place', (tester) async {
    await tester.pumpWidget(host());
    await open(tester);

    expect(find.text('Quick actions'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Quick actions')).dx - tester.getTopLeft(find.byType(FactoryBottomSheet)).dx,
      FactorySpacing.space4,
      reason: 'padded at the sides',
    );
    expect(find.text('Book again'), findsNothing);

    await tester.tap(find.text('Free today'));
    await tester.pumpAndSettle();
    expect(find.text('Search available=1'), findsOneWidget);
    expect(find.text('Quick actions'), findsNothing, reason: 'the sheet closes');
  });

  testWidgets('"Near me" opens Search sorted by distance; "Find a service" asks for the keyboard', (tester) async {
    await tester.pumpWidget(host());
    await open(tester);
    await tester.tap(find.text('Near me'));
    await tester.pumpAndSettle();
    expect(find.text('Search sort=DISTANCE'), findsOneWidget);

    GoRouter.of(tester.element(find.textContaining('Search sort'))).go('/');
    await open(tester);
    await tester.tap(find.text('Find a service'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Search focus='), findsOneWidget);
  });

  testWidgets('with a past visit the last service can be booked again in one tap', (tester) async {
    await tester.pumpWidget(host(history: [_visit('Haircut', 'Studio One'), _visit('Manicure', 'Nail Bar')]));
    await open(tester);

    expect(find.text('Book again'), findsOneWidget);
    expect(find.text('Haircut · Studio One'), findsOneWidget, reason: 'the newest visit');
    await tester.tap(find.text('Book again'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Provider p-Studio One'), findsOneWidget);
    expect(find.textContaining('book=1'), findsOneWidget);
    expect(find.textContaining('service=s-Haircut'), findsOneWidget);
  });

  testWidgets('a logged-in customer with no history, or when the history cannot load, is not offered "Book again"', (tester) async {
    await tester.pumpWidget(host(history: const []));
    await open(tester);
    expect(find.text('Book again'), findsNothing);
    expect(find.text('Find a service'), findsOneWidget);
  });

  testWidgets('a failing history is the same as none', (tester) async {
    await tester.pumpWidget(host(history: [_visit('Haircut', 'Studio One')], failing: true));
    await open(tester);
    expect(find.text('Book again'), findsNothing);
    expect(find.text('Near me'), findsOneWidget);
  });

  testWidgets('fits a 320 px phone with a large font in the dark theme', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(history: [_visit('A very long service name for a haircut', 'A Very Long Beauty Studio Name')]));
    await open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Book again'), findsOneWidget);
  });
}
