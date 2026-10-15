import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/beauty/data/beauty_api.dart';
import 'package:zairo/features/beauty/data/models/portfolio_item.dart';
import 'package:zairo/features/beauty/presentation/providers/beauty_providers.dart';
import 'package:zairo/features/workers/data/models/worker_profile.dart';
import 'package:zairo/features/workers/data/workers_api.dart';
import 'package:zairo/features/workers/presentation/providers/workers_providers.dart';
import 'package:zairo/features/workers/presentation/screens/worker_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeBeautyApi extends BeautyApi {
  _FakeBeautyApi(this._items) : super(DioClient(Dio()));

  final List<PortfolioItem> _items;

  @override
  Future<List<PortfolioItem>> listPortfolio(String masterId) async => _items;
}

class _FakeWorkersApi extends WorkersApi {
  _FakeWorkersApi({this.profile, this.failProfile = false}) : super(DioClient(Dio()));

  final WorkerProfile? profile;
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
}

WorkerProfile _profile({
  String kind = 'MASTER',
  double? rating = 4.5,
  List<WorkerService>? services,
  String? bio,
  List<WorkerReview> reviews = const [],
}) => WorkerProfile(
  id: 'w1',
  kind: kind,
  providerId: 'p1',
  providerName: 'Aigerim Beauty Studio',
  displayName: 'Aigerim K.',
  photoUrl: null,
  bio: bio,
  reviews: reviews,
  averageRating: rating,
  reviewCount: rating == null ? 0 : 2,
  services:
      services ??
      const [WorkerService(id: 's1', title: 'Haircut', durationMinutes: 60, price: 8000, currency: 'KZT')],
);

Widget _app(_FakeWorkersApi api, {List<PortfolioItem> work = const []}) => ProviderScope(
  // No automatic retry: a failed load must stay failed until the person taps retry.
  retry: (_, _) => null,
  overrides: [
    workersApiProvider.overrideWithValue(api),
    beautyApiProvider.overrideWithValue(_FakeBeautyApi(work)),
  ],
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

  testWidgets('shows the about-me text, the newest reviews with the business reply, and no reviewer names', (tester) async {
    final profile = _profile(
      bio: 'Ten years in colouring.',
      reviews: [
        WorkerReview(rating: 5, comment: 'Lovely work', createdAt: DateTime(2026, 10, 1), businessReply: 'Thank you!'),
        WorkerReview(rating: 4, comment: null, createdAt: DateTime(2026, 9, 20)),
      ],
    );
    await tester.pumpWidget(_app(_FakeWorkersApi(profile: profile)));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Ten years in colouring.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Lovely work'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Lovely work'), findsOneWidget);
    expect(find.text('Reply from the business'), findsOneWidget);
    expect(find.text('Thank you!'), findsOneWidget);
    expect(find.text('Oct 1, 2026'), findsOneWidget);
  });

  testWidgets('no about-me or reviews block when there is nothing to show', (tester) async {
    await tester.pumpWidget(_app(_FakeWorkersApi(profile: _profile())));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsNothing);
    expect(find.text('Reviews'), findsNothing);
  });

  testWidgets('a master shows a strip of their work that opens the portfolio; others do not', (tester) async {
    await tester.pumpWidget(
      _app(
        _FakeWorkersApi(profile: _profile()),
        work: const [PortfolioItem(id: 'i1', masterId: 'w1', imageUrl: 'https://img.example/1.jpg')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    await tester.ensureVisible(find.byType(Image).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.text('Portfolio w1'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        _FakeWorkersApi(profile: _profile(kind: 'STAFF')),
        work: const [PortfolioItem(id: 'i1', masterId: 'w1', imageUrl: 'https://img.example/1.jpg')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Work'), findsNothing);
  });
}
