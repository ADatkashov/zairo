import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/waitlist/data/models/waitlist_entry.dart';
import 'package:zairo/features/waitlist/data/waitlist_api.dart';
import 'package:zairo/features/waitlist/presentation/providers/waitlist_providers.dart';
import 'package:zairo/features/waitlist/presentation/widgets/no_times_waitlist.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeWaitlistApi extends WaitlistApi {
  _FakeWaitlistApi({Map<String, WaitlistEntry> waiting = const {}, this.failChanges = false})
    : _waiting = {...waiting},
      super(DioClient(Dio()));

  final Map<String, WaitlistEntry> _waiting;
  final bool failChanges;
  int joinCalls = 0;
  int leaveCalls = 0;
  DateTime? joinedDay;

  @override
  Future<Map<String, WaitlistEntry>> listEntries(String userId) async => {..._waiting};

  @override
  Future<void> join(String userId, String providerId, {DateTime? day}) async {
    joinCalls++;
    if (failChanges) throw Exception('boom');
    joinedDay = day;
    _waiting[providerId] = WaitlistEntry(providerId: providerId, from: day, to: day?.add(const Duration(days: 1)));
  }

  @override
  Future<void> leave(String userId, String providerId) async {
    leaveCalls++;
    if (failChanges) throw Exception('boom');
    _waiting.remove(providerId);
  }
}

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'user-1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
}

class _LoggedOutAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

Future<void> _pump(WidgetTester tester, _FakeWaitlistApi api, {bool loggedIn = true, double width = 400}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        waitlistApiProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(loggedIn ? _LoggedInAuthController.new : _LoggedOutAuthController.new),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SingleChildScrollView(child: NoTimesWaitlist(providerId: 'provider-1'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers one tap to be told when a time opens (any day), then confirms it and lets the customer leave', (
    tester,
  ) async {
    final api = _FakeWaitlistApi();
    await _pump(tester, api);

    expect(find.text('No open times'), findsOneWidget);
    expect(find.text('Which day?'), findsOneWidget);
    expect(find.text('Notify me'), findsOneWidget);

    await tester.tap(find.text('Notify me'));
    await tester.pumpAndSettle();

    expect(api.joinCalls, 1);
    expect(api.joinedDay, isNull);
    expect(find.text("You're on the waitlist"), findsOneWidget);
    expect(find.text('Notify me'), findsNothing);

    await tester.tap(find.text('Stop waiting'));
    await tester.pumpAndSettle();

    expect(api.leaveCalls, 1);
    expect(find.text('Notify me'), findsOneWidget);
  });

  testWidgets('joins for the day picked from the strip and says which day it is waiting for', (tester) async {
    final api = _FakeWaitlistApi();
    await _pump(tester, api);

    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notify me'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(api.joinedDay, DateTime(now.year, now.month, now.day + 1));
    expect(find.text("You're on the waitlist"), findsOneWidget);
    expect(find.textContaining('opens up on'), findsOneWidget);
  });

  testWidgets('picking "Any day" again clears a previously picked day', (tester) async {
    final api = _FakeWaitlistApi();
    await _pump(tester, api);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Any day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notify me'));
    await tester.pumpAndSettle();

    expect(api.joinedDay, isNull);
  });

  testWidgets('shows the waiting state straight away for a business the customer already waits for', (tester) async {
    await _pump(tester, _FakeWaitlistApi(waiting: {'provider-1': const WaitlistEntry(providerId: 'provider-1')}));

    expect(find.text("You're on the waitlist"), findsOneWidget);
    expect(find.text('Stop waiting'), findsOneWidget);
    expect(find.text('Which day?'), findsNothing);
  });

  testWidgets('a logged-out customer is sent to log in instead of joining', (tester) async {
    final api = _FakeWaitlistApi();
    await _pump(tester, api, loggedIn: false);

    await tester.tap(find.text('Notify me'));
    await tester.pumpAndSettle();

    expect(api.joinCalls, 0);
    expect(find.text('Log in'), findsWidgets);
  });

  testWidgets('says so when joining fails and stays tappable', (tester) async {
    final api = _FakeWaitlistApi(failChanges: true);
    await _pump(tester, api);

    await tester.tap(find.text('Notify me'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't update the waitlist. Try again."), findsOneWidget);
    expect(find.text('Notify me'), findsOneWidget);
  });
}
