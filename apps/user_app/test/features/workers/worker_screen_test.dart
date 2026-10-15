import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/workers/data/models/top_worker.dart';
import 'package:zairo/features/workers/data/models/worker_profile.dart';
import 'package:zairo/features/workers/data/workers_api.dart';
import 'package:zairo/features/workers/presentation/providers/workers_providers.dart';
import 'package:zairo/features/workers/presentation/screens/worker_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeWorkersApi extends WorkersApi {
  _FakeWorkersApi({this.profile, this.top = const [], this.failProfile = false}) : super(DioClient(Dio()));

  final WorkerProfile? profile;
  final List<TopWorker> top;
  bool failProfile;
  int profileCalls = 0;

  @override
  Future<WorkerProfile> getProfile(String workerId) async {
    profileCalls++;
    if (failProfile) {
      failProfile = false;
      throw Exception('offline');
    }
    return profile!;
  }

  @override
  Future<List<TopWorker>> listTop({int limit = 10, String? cityCode}) async {
    return top;
  }
}

WorkerProfile _profile({String kind = 'MASTER', double? rating = 4.5, List<WorkerService>? services}) => WorkerProfile(
  id: 'w1',
  kind: kind,
  providerId: 'p1',
  providerName: 'Aigerim Beauty Studio',
  displayName: 'Aigerim K.',
  photoUrl: null,
  averageRating: rating,
  reviewCount: rating == null ? 0 : 2,
  services:
      services ??
      const [WorkerService(id: 's1', title: 'Haircut', durationMinutes: 60, price: 8000, currency: 'KZT')],
);

Widget _app(_FakeWorkersApi api) => ProviderScope(
  overrides: [workersApiProvider.overrideWithValue(api)],
  child: MaterialApp.router(
    theme: factoryLightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const WorkerScreen(workerId: 'w1')),
        GoRoute(
          path: '/provider/:id',
          builder: (_, state) => Scaffold(
            body: Text(
              'Provider ${state.pathParameters['id']} book=${state.uri.queryParameters['book']} '
              'worker=${state.uri.queryParameters['worker']} kind=${state.uri.queryParameters['kind']}',
            ),
          ),
        ),
        GoRoute(
          path: '/portfolio/:masterId',
          builder: (_, state) => Scaffold(body: Text('Portfolio ${state.pathParameters['masterId']}')),
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('shows the master, their rating, business and services', (tester) async {
    await tester.pumpWidget(_app(_FakeWorkersApi(profile: _profile())));
    await tester.pumpAndSettle();

    expect(find.text('Aigerim K.'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('(2)'), findsOneWidget);
    expect(find.text('Aigerim Beauty Studio'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('60 min'), findsOneWidget);
    expect(find.text('Book'), findsOneWidget);
    expect(find.text('Portfolio'), findsOneWidget);
  });

  testWidgets('a worker with no reviews shows text instead of a rating, and no services shows a note', (tester) async {
    await tester.pumpWidget(_app(_FakeWorkersApi(profile: _profile(kind: 'STAFF', rating: null, services: const []))));
    await tester.pumpAndSettle();

    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.byType(FactoryRatingLabel), findsNothing);
    expect(find.text('No services listed yet.'), findsOneWidget);
    // Only a master has a portfolio.
    expect(find.text('Portfolio'), findsNothing);
  });

  testWidgets('Book opens the business at its booking steps with this master already picked', (tester) async {
    await tester.pumpWidget(_app(_FakeWorkersApi(profile: _profile())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();

    expect(find.text('Provider p1 book=1 worker=w1 kind=MASTER'), findsOneWidget);
  });

  testWidgets('tapping the business opens it, Portfolio opens the master\'s photos', (tester) async {
    await tester.pumpWidget(_app(_FakeWorkersApi(profile: _profile())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aigerim Beauty Studio'));
    await tester.pumpAndSettle();
    expect(find.text('Provider p1 book=null worker=null kind=null'), findsOneWidget);

    await tester.pumpWidget(_app(_FakeWorkersApi(profile: _profile())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portfolio'));
    await tester.pumpAndSettle();
    expect(find.text('Portfolio w1'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that loads the page', (tester) async {
    final api = _FakeWorkersApi(profile: _profile(), failProfile: true);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Couldn\'t load this master.'), findsOneWidget);

    await tester.tap(find.byType(FactoryButton));
    await tester.pumpAndSettle();

    expect(find.text('Aigerim K.'), findsOneWidget);
    expect(api.profileCalls, 2);
  });
}
