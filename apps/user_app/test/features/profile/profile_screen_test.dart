import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/favorites/data/favorites_api.dart';
import 'package:zairo/features/favorites/data/models/favorite_provider.dart';
import 'package:zairo/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:zairo/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:zairo/features/loyalty/data/api/loyalty_api.dart';
import 'package:zairo/features/loyalty/data/models/loyalty.dart';
import 'package:zairo/features/loyalty/presentation/providers/loyalty_providers.dart';
import 'package:zairo/features/profile/presentation/screens/profile_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'user-1', email: 'aigerim@example.com', displayName: 'Aigerim K.', role: 'CUSTOMER');
  }
}

class _LoggedOutAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi(this._bookings) : super(DioClient(Dio()));

  final List<Booking> _bookings;

  @override
  Future<List<Booking>> listMyBookings(String userId) async => _bookings;
}

class _FakeFavoritesApi extends FavoritesApi {
  _FakeFavoritesApi(this._favorites) : super(DioClient(Dio()));

  final List<FavoriteProvider> _favorites;

  @override
  Future<List<FavoriteProvider>> listFavorites(String userId) async => _favorites;
}

class _FakeLoyaltyApi extends LoyaltyApi {
  _FakeLoyaltyApi(this._rows) : super(DioClient(Dio()));

  final List<LoyaltyBusinessSummary> _rows;

  @override
  Future<List<LoyaltyBusinessSummary>> myLoyalty() async => _rows;
}

LoyaltyBusinessSummary _points(String id, int balance, {int expiring = 0}) => LoyaltyBusinessSummary(
  providerId: id,
  providerName: id,
  programEnabled: true,
  pointsBalance: balance,
  lifetimeEarned: balance,
  pointsExpiringSoon30d: expiring,
);

/// The menu is a long list: a tall window builds the My rewards row without scrolling.
void _useTallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _wrap(AuthController controller, {List<Override> extraOverrides = const []}) => ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => controller), ...extraOverrides],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfileScreen(),
      ),
    );

void main() {
  testWidgets('shows a login prompt and create-account action when logged out', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedOutAuthController()));
    await tester.pumpAndSettle();

    expect(find.text("You're not logged in"), findsOneWidget);
    expect(find.text('Log in to book and review providers'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('shows the avatar initials, name, email and menu when logged in', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInAuthController()));
    await tester.pumpAndSettle();

    expect(find.text('AK'), findsOneWidget);
    expect(find.text('Aigerim K.'), findsOneWidget);
    expect(find.text('aigerim@example.com'), findsOneWidget);
    // The menu is a lazy list: rows below the fold only exist once scrolled to.
    await tester.scrollUntilVisible(find.text('My vehicles'), 200);
    expect(find.text('My vehicles'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Log out'), 200);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('the header is brand-coloured with readable text, and menu rows carry tinted icon plates', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInAuthController()));
    await tester.pumpAndSettle();

    final colors = FactoryColors.light;
    // Name and email sit on the green header, so they use onPrimary.
    expect(tester.widget<Text>(find.text('Aigerim K.')).style?.color, colors.onPrimary);
    expect(tester.widget<Text>(find.text('aigerim@example.com')).style?.color?.a, closeTo(0.82, 0.01));

    // The favourites row shows its heart on a coral plate, not a bare grey outline.
    await tester.scrollUntilVisible(find.text('My vehicles'), 200);
    final plates = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.decoration is BoxDecoration && (c.decoration! as BoxDecoration).color == colors.coralTint);
    expect(plates, isNotEmpty);
  });

  testWidgets('shows booking and favorite counts in the stat row', (tester) async {
    final booking = Booking(
      id: 'booking-1',
      userId: 'user-1',
      serviceId: 'service-1',
      availabilitySlotId: 'slot-1',
      status: 'CONFIRMED',
      totalPrice: 30,
      createdAt: DateTime(2026, 1, 1),
    );
    final favorite = FavoriteProvider(
      id: 'provider-1',
      name: 'Salon',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      services: const [],
      favoritedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(_wrap(
      _LoggedInAuthController(),
      extraOverrides: [
        bookingApiProvider.overrideWithValue(_FakeBookingApi([booking])),
        favoritesApiProvider.overrideWithValue(_FakeFavoritesApi([favorite])),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('My bookings'), findsOneWidget);
    expect(find.widgetWithText(FactoryStatTile, 'My favorites'), findsOneWidget);
  });

  testWidgets('tapping the favorites stat tile opens the favorites list (no longer a bottom-nav tab)',
      (tester) async {
    final favorite = FavoriteProvider(
      id: 'provider-1',
      name: 'Salon',
      vertical: 'beauty',
      status: 'ACTIVE',
      hasOpenAvailability: true,
      services: const [],
      favoritedAt: DateTime(2026, 1, 1),
    );

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
          favoritesApiProvider.overrideWithValue(_FakeFavoritesApi([favorite])),
        ],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FactoryStatTile, 'My favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Salon'), findsOneWidget);
  });

  testWidgets('tapping the bookings stat tile goes to the bookings page', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/bookings', builder: (_, _) => const Scaffold(body: Text('Bookings page'))),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(_LoggedInAuthController.new)],
        child: MaterialApp.router(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My bookings'));
    await tester.pumpAndSettle();

    expect(find.text('Bookings page'), findsOneWidget);
  });

  testWidgets('My rewards shows the total points and how many businesses they are in', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(
      _wrap(
        _LoggedInAuthController(),
        extraOverrides: [
          loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi([_points('a', 120), _points('b', 200), _points('c', 0)])),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('320 pts · 2 businesses'), findsOneWidget);
    expect(find.textContaining('expire'), findsNothing);
  });

  testWidgets('My rewards warns when some points expire within 30 days', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(
      _wrap(
        _LoggedInAuthController(),
        extraOverrides: [
          loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi([_points('a', 120, expiring: 50)])),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('120 pts · 1 business'), findsOneWidget);
    expect(find.text('50 pts expire within 30 days'), findsOneWidget);
  });

  testWidgets('My rewards has no hint before the first points', (tester) async {
    _useTallWindow(tester);
    await tester.pumpWidget(
      _wrap(_LoggedInAuthController(), extraOverrides: [loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi([]))]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(' pts'), findsNothing);
  });

  testWidgets('Profile fits a 320 px phone with a large font in the dark theme, signed in and out', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget app(AuthController controller) => ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: factoryDarkTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ProfileScreen(),
      ),
    );

    await tester.pumpWidget(app(_LoggedOutAuthController()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app(_LoggedInAuthController()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
