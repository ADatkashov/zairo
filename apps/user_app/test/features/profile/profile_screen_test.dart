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
import 'package:zairo/features/city/data/models/city.dart';
import 'package:zairo/features/city/presentation/providers/city_providers.dart';
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

  testWidgets('the header sits on the page: name and e-mail, the avatar with a camera badge, no repeated e-mail', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInAuthController()));
    await tester.pumpAndSettle();

    final colors = FactoryColors.light;
    // Plain page text, not the white-on-green of the old header.
    expect(tester.widget<Text>(find.text('Aigerim K.')).style?.color, isNot(colors.onPrimary));
    expect(tester.widget<Text>(find.text('aigerim@example.com')).style?.color, colors.textSecondary);
    expect(find.byIcon(Symbols.photo_camera_rounded), findsOneWidget);
    // The e-mail is under the name; the details card doesn't say it a second time.
    expect(find.text('aigerim@example.com'), findsOneWidget);

    // The favourites row shows its heart on a coral plate, not a bare grey outline.
    await tester.scrollUntilVisible(find.text('My vehicles'), 200);
    final plates = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.decoration is BoxDecoration && (c.decoration! as BoxDecoration).color == colors.coralTint);
    expect(plates, isNotEmpty);
  });

  testWidgets('the details card shows the birthday and city, and nudges to add a missing birthday', (tester) async {
    await tester.pumpWidget(_wrap(
      _LoggedInAuthController(),
      extraOverrides: [
        userCurrentCityProvider.overrideWith(
          (ref) async => City(code: 'ALA', name: 'Almaty', countryCode: 'KZ', timezone: 'Asia/Almaty', currency: 'KZT', active: true),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('Add your birthday to get a gift'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Almaty'), findsOneWidget);
  });

  testWidgets('a known birthday is shown as a date and the nudge goes away', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInWithBirthdayAuthController()));
    await tester.pumpAndSettle();

    expect(find.text('12 May 1995'), findsNothing); // formatted for the locale, not ISO
    expect(find.textContaining('1995'), findsOneWidget);
    expect(find.text('Not set'), findsNothing);
    expect(find.text('Add your birthday to get a gift'), findsNothing);
  });

  testWidgets('the settings card lists cards, vehicles, security and the current language, and opens them', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/settings/security', builder: (_, _) => const Scaffold(body: Text('Security page'))),
      GoRoute(path: '/settings', builder: (_, _) => const Scaffold(body: Text('Settings page'))),
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

    await tester.scrollUntilVisible(find.text('Payment cards'), 200);
    expect(find.text('Payment cards'), findsOneWidget);
    expect(find.text('English'), findsOneWidget); // the active language, named in its own script

    await tester.scrollUntilVisible(find.text('Security'), 200);
    await tester.ensureVisible(find.text('Security'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    expect(find.text('Security page'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('English'), 200);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings page'), findsOneWidget);
  });

  testWidgets('log out is a plain card at the end that asks before ending the session', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInAuthController()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Log out'), 200);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out of your account?'), findsOneWidget);
    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();
    expect(find.text('Log out of your account?'), findsNothing);
  });

  testWidgets('shows booking and favorite counts on their rows', (tester) async {
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

    expect(find.text('My bookings'), findsOneWidget);
    expect(find.text('My favorites'), findsOneWidget);
    // Each count sits on the right of its row.
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('tapping the favorites row opens the favorites list (no longer a bottom-nav tab)',
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

    await tester.tap(find.text('My favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Salon'), findsOneWidget);
  });

  testWidgets('tapping the bookings row goes to the bookings page', (tester) async {
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
