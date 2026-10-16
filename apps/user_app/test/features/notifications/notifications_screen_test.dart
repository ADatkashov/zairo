import 'package:intl/intl.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/notifications/data/models/app_notification.dart';
import 'package:zairo/features/notifications/data/notifications_api.dart';
import 'package:zairo/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:zairo/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeNotificationsApi extends NotificationsApi {
  _FakeNotificationsApi(this._notifications) : super(DioClient(Dio()));

  final List<AppNotification> _notifications;
  final List<String> markedReadIds = [];
  bool markedAllRead = false;

  @override
  Future<List<AppNotification>> listNotifications(String userId) async =>
      _notifications;

  @override
  Future<int> unreadCount(String userId) async =>
      _notifications.where((n) => !n.read).length;

  @override
  Future<void> markRead(String userId, String notificationId) async {
    markedReadIds.add(notificationId);
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    _notifications[index] = AppNotification(
      id: _notifications[index].id,
      type: _notifications[index].type,
      title: _notifications[index].title,
      body: _notifications[index].body,
      read: true,
      createdAt: _notifications[index].createdAt,
    );
  }

  @override
  Future<void> markAllRead(String userId) async {
    markedAllRead = true;
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = AppNotification(
        id: _notifications[i].id,
        type: _notifications[i].type,
        title: _notifications[i].title,
        body: _notifications[i].body,
        read: true,
        createdAt: _notifications[i].createdAt,
      );
    }
  }
}

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(
      id: 'user-1',
      email: 'a@example.com',
      displayName: 'A',
      role: 'CUSTOMER',
    );
  }
}

class _LoggedOutAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

void main() {
  testWidgets('shows a login gate when logged out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsApiProvider.overrideWithValue(
            _FakeNotificationsApi(const []),
          ),
          authControllerProvider.overrideWith(_LoggedOutAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in to see your notifications'), findsOneWidget);
  });

  testWidgets('shows an empty state with no notifications', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsApiProvider.overrideWithValue(
            _FakeNotificationsApi(const []),
          ),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('lists notifications and tapping an unread one marks it read', (
    tester,
  ) async {
    final notifications = [
      AppNotification(
        id: 'n1',
        type: 'BOOKING_CONFIRMED',
        title: 'Booking confirmed',
        body: 'Your booking is confirmed.',
        read: false,
        createdAt: DateTime(2026, 1, 1, 10),
      ),
    ];
    final fakeApi = _FakeNotificationsApi(notifications);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsApiProvider.overrideWithValue(fakeApi),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Booking confirmed'), findsOneWidget);
    expect(find.text('Your booking is confirmed.'), findsOneWidget);

    await tester.tap(find.text('Booking confirmed'));
    await tester.pumpAndSettle();

    expect(fakeApi.markedReadIds, ['n1']);
  });

  testWidgets(
    'mark all read button only shows when something is unread, and clears the list',
    (tester) async {
      final notifications = [
        AppNotification(
          id: 'n1',
          type: 'BOOKING_CONFIRMED',
          title: 'Booking confirmed',
          body: 'Your booking is confirmed.',
          read: false,
          createdAt: DateTime(2026, 1, 1, 10),
        ),
        AppNotification(
          id: 'n2',
          type: 'BOOKING_CANCELLED',
          title: 'Booking cancelled',
          body: 'Your booking was cancelled.',
          read: true,
          createdAt: DateTime(2026, 1, 2, 10),
        ),
      ];
      final fakeApi = _FakeNotificationsApi(notifications);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsApiProvider.overrideWithValue(fakeApi),
            authControllerProvider.overrideWith(_LoggedInAuthController.new),
          ],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mark all read'), findsOneWidget);
      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(fakeApi.markedAllRead, isTrue);
      expect(find.text('Mark all read'), findsNothing);
    },
  );

  testWidgets(
    'tapping a booking notification marks it read and opens Bookings',
    (tester) async {
      final fakeApi = _FakeNotificationsApi([
        AppNotification(
          id: 'n1',
          type: 'BOOKING_REMINDER',
          title: 'Reminder',
          body: 'Your visit is tomorrow.',
          read: false,
          createdAt: DateTime(2026, 1, 1, 10),
        ),
      ]);
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/bookings',
            builder: (_, _) => const Scaffold(body: Text('Bookings page')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsApiProvider.overrideWithValue(fakeApi),
            authControllerProvider.overrideWith(_LoggedInAuthController.new),
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

      await tester.tap(find.text('Reminder'));
      await tester.pumpAndSettle();

      expect(fakeApi.markedReadIds, ['n1']);
      expect(find.text('Bookings page'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a "time opened up" waitlist notification marks it read and opens Search',
    (tester) async {
      final fakeApi = _FakeNotificationsApi([
        AppNotification(
          id: 'n1',
          type: 'WAITLIST_SLOT_OPENED',
          title: 'A time just opened up',
          body: 'A time opened up at Salon.',
          read: false,
          createdAt: DateTime(2026, 1, 1, 10),
        ),
      ]);
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (_, _) => const Scaffold(body: Text('Search page')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsApiProvider.overrideWithValue(fakeApi),
            authControllerProvider.overrideWith(_LoggedInAuthController.new),
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

      await tester.tap(find.text('A time just opened up'));
      await tester.pumpAndSettle();

      expect(fakeApi.markedReadIds, ['n1']);
      expect(find.text('Search page'), findsOneWidget);
    },
  );

  testWidgets(
    'a read notification with no destination does nothing when tapped',
    (tester) async {
      final fakeApi = _FakeNotificationsApi([
        AppNotification(
          id: 'n1',
          type: 'SOMETHING_NEW',
          title: 'Hello',
          body: 'No route for this one.',
          read: true,
          createdAt: DateTime(2026, 1, 1, 10),
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsApiProvider.overrideWithValue(fakeApi),
            authControllerProvider.overrideWith(_LoggedInAuthController.new),
          ],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hello'));
      await tester.pumpAndSettle();

      expect(fakeApi.markedReadIds, isEmpty);
      expect(find.text('Hello'), findsOneWidget);
    },
  );

  testWidgets('groups notifications under Today, Yesterday and a date', (
    tester,
  ) async {
    final now = DateTime.now();
    AppNotification at(String id, DateTime when) => AppNotification(
      id: id,
      type: 'BOOKING_CONFIRMED',
      title: 'Title $id',
      body: 'Body $id',
      read: true,
      createdAt: when,
    );
    final notifications = [
      at('a', now),
      at('b', now.subtract(const Duration(days: 1))),
      at('c', now.subtract(const Duration(days: 10))),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsApiProvider.overrideWithValue(
            _FakeNotificationsApi(notifications),
          ),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    final older = now.subtract(const Duration(days: 10));
    expect(find.text(DateFormat.MMMMd('en').format(older)), findsOneWidget);
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('Title c'), findsOneWidget);
  });
}
