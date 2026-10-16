import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/workers/data/workers_api.dart';
import 'package:zairo/features/workers/presentation/providers/workers_providers.dart';
import 'package:zairo/features/workers/presentation/widgets/favorite_worker_button.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeWorkersApi extends WorkersApi {
  _FakeWorkersApi({this.failToggle = false, this.failCheck = false, this.gate}) : super(DioClient(Dio()));

  bool _favorite = false;
  final bool failToggle;
  final bool failCheck;

  /// When set, the "is a favorite" answer waits for it (the heart is in its loading state meanwhile).
  final Completer<bool>? gate;
  int addCalls = 0;
  int removeCalls = 0;

  @override
  Future<bool> isFavoriteWorker(String userId, String workerId) async {
    if (failCheck) throw Exception('offline');
    if (gate != null) return gate!.future;
    return _favorite;
  }

  @override
  Future<void> addFavoriteWorker(String userId, String workerId) async {
    addCalls++;
    if (failToggle) throw Exception('offline');
    _favorite = true;
  }

  @override
  Future<void> removeFavoriteWorker(String userId, String workerId) async {
    removeCalls++;
    if (failToggle) throw Exception('offline');
    _favorite = false;
  }
}

class _LoggedIn extends AuthController {
  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'user-1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
}

class _LoggedOut extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

Widget _app(_FakeWorkersApi api, {bool loggedIn = true}) => ProviderScope(
  retry: (_, _) => null,
  overrides: [
    workersApiProvider.overrideWithValue(api),
    authControllerProvider.overrideWith(loggedIn ? _LoggedIn.new : _LoggedOut.new),
  ],
  child: MaterialApp(
    theme: factoryLightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: FavoriteWorkerButton(workerId: 'w1')),
  ),
);

double? _fill(WidgetTester tester) => tester.widget<Icon>(find.byIcon(Symbols.favorite_rounded)).fill;

void main() {
  testWidgets('a guest is sent to log in instead of the heart doing nothing', (tester) async {
    await tester.pumpWidget(_app(_FakeWorkersApi(), loggedIn: false));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add to my masters'), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.favorite_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsWidgets);
  });

  testWidgets('an outline heart adds the master, then a filled heart removes them', (tester) async {
    final api = _FakeWorkersApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(_fill(tester), isNot(1));

    await tester.tap(find.byIcon(Symbols.favorite_rounded));
    await tester.pumpAndSettle();
    expect(api.addCalls, 1);
    expect(_fill(tester), 1);
    expect(find.byTooltip('Remove from my masters'), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.favorite_rounded));
    await tester.pumpAndSettle();
    expect(api.removeCalls, 1);
    expect(_fill(tester), 0);
  });

  testWidgets('a failed toggle keeps the heart as it was and says so', (tester) async {
    final api = _FakeWorkersApi(failToggle: true);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.favorite_rounded));
    await tester.pumpAndSettle();

    expect(api.addCalls, 1);
    expect(_fill(tester), isNot(1));
    expect(find.text("Couldn't update your masters. Please try again."), findsOneWidget);
  });

  testWidgets('the heart is disabled while the state loads', (tester) async {
    final gate = Completer<bool>();
    await tester.pumpWidget(_app(_FakeWorkersApi(gate: gate)));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);

    gate.complete(false);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNotNull);
  });

  testWidgets('the heart is disabled when the state cannot be read', (tester) async {
    await tester.pumpWidget(_app(_FakeWorkersApi(failCheck: true)));
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
  });
}
