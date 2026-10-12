import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/reviews/data/models/public_review.dart';
import 'package:zairo/features/reviews/data/reviews_api.dart';
import 'package:zairo/features/reviews/presentation/providers/reviews_providers.dart';
import 'package:zairo/features/reviews/presentation/widgets/reviews_preview.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeApi extends ReviewsApi {
  _FakeApi({required this.summary, this.reviews = const [], this.fail = false})
    : super(DioClient(Dio()));

  final ReviewSummary summary;
  final List<PublicReview> reviews;
  final bool fail;
  int? requestedSize;

  @override
  Future<ReviewSummary> getSummary(String providerId) async {
    if (fail) throw Exception('boom');
    return summary;
  }

  @override
  Future<PublicReviewsPage> getPublicReviews(
    String providerId, {
    int size = 20,
    int? rating,
    bool withCommentOnly = false,
    ReviewSort sort = ReviewSort.newest,
  }) async {
    requestedSize = size;
    if (fail) throw Exception('boom');
    return PublicReviewsPage(
      reviews: reviews.take(size).toList(),
      hasMore: reviews.length > size,
    );
  }
}

PublicReview _r(int i) => PublicReview(
  id: 'r$i',
  authorName: 'Author $i',
  rating: 5,
  comment: 'Comment $i',
  createdAt: DateTime(2026, 3, i + 1),
);

Future<GoRouter> _pump(WidgetTester tester, _FakeApi api) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: ListView(
            children: const [
              ReviewsPreview(providerId: 'p-1', providerName: 'Studio'),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/provider/:id/reviews',
        builder: (_, state) => Text('all ${state.pathParameters['id']}'),
      ),
    ],
  );
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reviewsApiProvider.overrideWithValue(api)],
      child: MaterialApp.router(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets(
    'shows the average, only the latest three reviews and a link to all',
    (tester) async {
      final api = _FakeApi(
        summary: const ReviewSummary(
          average: 4.8,
          total: 5,
          distribution: [0, 0, 0, 1, 4],
        ),
        reviews: [for (var i = 0; i < 5; i++) _r(i)],
      );
      await _pump(tester, api);

      expect(api.requestedSize, reviewsPreviewCount);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('Based on 5 reviews'), findsOneWidget);
      expect(find.text('Comment 0'), findsOneWidget);
      expect(find.text('Comment 2'), findsOneWidget);
      expect(find.text('Comment 3'), findsNothing);

      await tester.tap(find.text('All reviews'));
      await tester.pumpAndSettle();
      expect(find.text('all p-1'), findsOneWidget);
    },
  );

  testWidgets('renders nothing without reviews or when loading them fails', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeApi(
        summary: const ReviewSummary(
          average: null,
          total: 0,
          distribution: [0, 0, 0, 0, 0],
        ),
      ),
    );
    expect(find.text('Reviews'), findsNothing);

    await _pump(
      tester,
      _FakeApi(
        summary: const ReviewSummary(
          average: 5,
          total: 1,
          distribution: [0, 0, 0, 0, 1],
        ),
        fail: true,
      ),
    );
    expect(find.text('Reviews'), findsNothing);
    expect(find.byType(FactoryErrorState), findsNothing);
  });
}
