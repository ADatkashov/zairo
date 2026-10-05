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
}
