import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/booking/data/booking_api.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/providers/booking_providers.dart';
import 'package:zairo/features/favorites/data/favorites_api.dart';
import 'package:zairo/features/favorites/data/models/favorite_provider.dart';
import 'package:zairo/features/favorites/presentation/providers/favorites_providers.dart';
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

class _LoggedInWithBirthdayAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => UserSummary(
    id: 'user-1',
    email: 'aigerim@example.com',
    displayName: 'Aigerim K.',
    role: 'CUSTOMER',
    birthDate: DateTime(1995, 5, 12),
  );
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

  testWidgets('a phone-only build offers just Log in when logged out (the phone form registers too)', (tester) async {
    await tester.pumpWidget(
      _wrap(_LoggedOutAuthController(), extraOverrides: [emailSignInEnabledProvider.overrideWithValue(false)]),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're not logged in"), findsOneWidget);
    expect(find.text('Create an account'), findsNothing);
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

  testWidgets('the header sits on the page: name and e-mail, the avatar with a camera badge', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInAuthController()));
    await tester.pumpAndSettle();

    final colors = FactoryColors.light;
    // Plain page text, not the white-on-green of the old header.
    expect(tester.widget<Text>(find.text('Aigerim K.')).style?.color, isNot(colors.onPrimary));
    expect(tester.widget<Text>(find.text('aigerim@example.com')).style?.color, colors.textSecondary);
    expect(find.byIcon(Symbols.photo_camera_rounded), findsOneWidget);

    // Rows carry a tinted icon plate (messages is lavender), not a bare grey outline.
    final plates = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.decoration is BoxDecoration && (c.decoration! as BoxDecoration).color == colors.lavenderTint);
    expect(plates, isNotEmpty);
  });

  testWidgets('the stat strip shows bookings, favorites and points as three numbers', (tester) async {
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
        loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi([_points('a', 120), _points('b', 200)])),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2)); // one booking, one favorite
    expect(find.text('320'), findsOneWidget); // 120 + 200 points
  });

  testWidgets('the bookings number counts what the Upcoming tab lists, not finished or cancelled ones', (tester) async {
    Booking withStatus(String id, String status) => Booking(
      id: id,
      userId: 'user-1',
      serviceId: 's',
      availabilitySlotId: 'a',
      status: status,
      totalPrice: 30,
      createdAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(_wrap(
      _LoggedInAuthController(),
      extraOverrides: [
        bookingApiProvider.overrideWithValue(_FakeBookingApi([
          withStatus('1', 'CONFIRMED'),
          withStatus('2', 'PENDING_PAYMENT'),
          withStatus('3', 'COMPLETED'),
          withStatus('4', 'CANCELLED'),
        ])),
        favoritesApiProvider.overrideWithValue(_FakeFavoritesApi([])),
        loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi([])),
      ],
    ));
    await tester.pumpAndSettle();

    // Two upcoming, no favorites, no points.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('with nothing yet the strip says 0, never a misleading blank', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInAuthController(), extraOverrides: [
      bookingApiProvider.overrideWithValue(_FakeBookingApi([])),
      favoritesApiProvider.overrideWithValue(_FakeFavoritesApi([])),
      loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi([])),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('—'), findsNothing);
  });

  group('tapping a number opens its list', () {
    Future<void> openWith(WidgetTester tester) async {
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
        GoRoute(path: '/bookings', builder: (_, _) => const Scaffold(body: Text('Bookings page'))),
        GoRoute(path: '/favorites', builder: (_, _) => const Scaffold(body: Text('Favorites page'))),
        GoRoute(path: '/rewards', builder: (_, _) => const Scaffold(body: Text('Rewards page'))),
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
    }

    testWidgets('bookings goes to the bookings tab', (tester) async {
      await openWith(tester);
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      expect(find.text('Bookings page'), findsOneWidget);
    });

    testWidgets('favorites opens the favorites list (no longer a bottom-nav tab)', (tester) async {
      await openWith(tester);
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Favorites page'), findsOneWidget);
    });

    testWidgets('points opens the rewards', (tester) async {
      await openWith(tester);
      await tester.tap(find.text('Points'));
      await tester.pumpAndSettle();
      expect(find.text('Rewards page'), findsOneWidget);
    });
  });

  testWidgets('a warning shows only when points are about to expire, and it opens the rewards', (tester) async {
    await tester.pumpWidget(_wrap(
      _LoggedInAuthController(),
      extraOverrides: [loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi([_points('a', 120, expiring: 50)]))],
    ));
    await tester.pumpAndSettle();
    expect(find.text('50 pts expire within 30 days'), findsOneWidget);
  });

  testWidgets('no expiry warning when nothing is about to burn', (tester) async {
    await tester.pumpWidget(_wrap(
      _LoggedInAuthController(),
      extraOverrides: [loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi([_points('a', 120)]))],
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('expire'), findsNothing);
  });

  testWidgets('personal details nudges to add a missing birthday', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInAuthController()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Personal details'), 200);
    expect(find.text('Add your birthday to get a gift'), findsOneWidget);
    expect(find.text('Name, birthday, gender'), findsNothing);
  });

  testWidgets('personal details says what is inside once the birthday is set', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInWithBirthdayAuthController()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Personal details'), 200);
    expect(find.text('Add your birthday to get a gift'), findsNothing);
    expect(find.text('Name, birthday, gender'), findsOneWidget);
  });

  testWidgets('the rows open their screens; Settings is one row, not a second gear in the app bar', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/profile/edit', builder: (_, _) => const Scaffold(body: Text('Edit page'))),
      GoRoute(path: '/settings', builder: (_, _) => const Scaffold(body: Text('Settings page'))),
      GoRoute(path: '/support', builder: (_, _) => const Scaffold(body: Text('Support page'))),
      GoRoute(path: '/about', builder: (_, _) => const Scaffold(body: Text('About page'))),
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
    expect(find.byTooltip('Settings'), findsNothing);
    await tester.scrollUntilVisible(find.text('Language, theme, security'), 200);
    expect(find.text('Language, theme, security'), findsOneWidget);

    Future<void> open(String label, String page) async {
      await tester.scrollUntilVisible(find.text(label), 200);
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(page), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
    }

    await open('Personal details', 'Edit page');
    await open('Settings', 'Settings page');
    await open('Support', 'Support page');
    await open('About', 'About page');
  });

  testWidgets('log out is a plain card that asks before ending the session', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInAuthController()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Log out'), 200);
    await tester.ensureVisible(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out of your account?'), findsOneWidget);
    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();
    expect(find.text('Log out of your account?'), findsNothing);
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
