import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/reviews/data/models/public_review.dart';
import 'package:zairo/features/reviews/data/reviews_api.dart';
import 'package:zairo/features/reviews/presentation/providers/reviews_providers.dart';
import 'package:zairo/features/reviews/presentation/screens/reviews_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeApi extends ReviewsApi {
  _FakeApi({
    required this.summary,
    this.reviews = const [],
    this.hasMore = false,
  }) : super(DioClient(Dio()));

  final ReviewSummary summary;
  final List<PublicReview> reviews;
  final bool hasMore;
  final requestedSizes = <int>[];
  final calls = <({int? rating, bool withCommentOnly, ReviewSort sort})>[];

  @override
  Future<ReviewSummary> getSummary(String providerId) async => summary;

  @override
  Future<PublicReviewsPage> getPublicReviews(
    String providerId, {
    int size = 20,
    int? rating,
    bool withCommentOnly = false,
    ReviewSort sort = ReviewSort.newest,
  }) async {
    requestedSizes.add(size);
    calls.add((rating: rating, withCommentOnly: withCommentOnly, sort: sort));
    return PublicReviewsPage(reviews: reviews, hasMore: hasMore);
  }
}

PublicReview _review(
  String id, {
  String? comment,
  String? reply,
  int rating = 5,
}) => PublicReview(
  id: id,
  authorName: 'Aisha K.',
  rating: rating,
  comment: comment,
  createdAt: DateTime(2026, 3, 14),
  businessReply: reply,
);

Future<void> _pump(
  WidgetTester tester,
  _FakeApi api, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reviewsApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReviewsScreen(providerId: 'p-1', providerName: 'Studio'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('model parsing tolerates null average, short distribution and missing reply', () {
    final summary = ReviewSummary.fromJson({
      'average': null,
      'total': 0,
      'distribution': [0, 0],
    });
    expect(summary.average, isNull);
    expect(summary.distribution, [0, 0, 0, 0, 0]);

    final page = PublicReviewsPage.fromJson({
      'content': [
        {
          'id': 'r1',
          'authorName': 'Aisha K.',
          'rating': 4,
          'comment': null,
          'createdAt': '2026-03-14T10:00:00Z',
          'businessReply': 'Thanks',
          'businessReplyAt': '2026-03-15T10:00:00Z',
        },
      ],
      'last': false,
    });
    expect(page.hasMore, isTrue);
    expect(page.reviews.single.businessReply, 'Thanks');
    expect(page.reviews.single.comment, isNull);
  });

  testWidgets(
    'shows summary, distribution, review text and the business reply',
    (tester) async {
      final api = _FakeApi(
        summary: const ReviewSummary(
          average: 4.6,
          total: 10,
          distribution: [0, 0, 1, 2, 7],
        ),
        reviews: [
          _review('r1', comment: 'Great place', reply: 'Thank you!'),
          _review('r2', rating: 3),
        ],
      );
      await _pump(tester, api);

      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('Based on 10 reviews'), findsOneWidget);
      expect(find.text('Great place'), findsOneWidget);
      expect(find.text('Reply from the business'), findsOneWidget);
      expect(find.text('Thank you!'), findsOneWidget);
      expect(find.text('Aisha K.'), findsNWidgets(2));
      expect(find.text('Show more'), findsNothing);
    },
  );

  testWidgets('empty state when there are no reviews', (tester) async {
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
    expect(find.text('No reviews yet'), findsOneWidget);
  });

  testWidgets('"Show more" asks for a bigger page', (tester) async {
    final api = _FakeApi(
      summary: const ReviewSummary(
        average: 5,
        total: 30,
        distribution: [0, 0, 0, 0, 30],
      ),
      reviews: [_review('r1', comment: 'x')],
      hasMore: true,
    );
    await _pump(tester, api);
    expect(api.requestedSizes, [20]);

    await tester.ensureVisible(find.text('Show more'));
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(api.requestedSizes.last, 40);
  });

  testWidgets('filter and sort chips re-query the server and restart paging', (
    tester,
  ) async {
    final api = _FakeApi(
      summary: const ReviewSummary(
        average: 5,
        total: 30,
        distribution: [0, 0, 0, 0, 30],
      ),
      reviews: [_review('r1', comment: 'x')],
      hasMore: true,
    );
    await _pump(tester, api);
    await tester.ensureVisible(find.text('Show more'));
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(api.requestedSizes.last, 40);

    await tester.tap(find.text('With text'));
    await tester.pumpAndSettle();
    expect(api.calls.last, (
      rating: null,
      withCommentOnly: true,
      sort: ReviewSort.newest,
    ));
    expect(
      api.requestedSizes.last,
      20,
      reason: 'a new filter starts from the first page',
    );

    await tester.tap(find.text('Highest rated'));
    await tester.pumpAndSettle();
    expect(api.calls.last, (
      rating: null,
      withCommentOnly: true,
      sort: ReviewSort.highest,
    ));

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(api.calls.last.withCommentOnly, isFalse);
    expect(api.calls.last.rating, isNull);
  });

  testWidgets(
    'a star chip filters, tapping it again clears, and an empty result offers a reset',
    (tester) async {
      final api = _FakeApi(
        summary: const ReviewSummary(
          average: 5,
          total: 30,
          distribution: [0, 0, 0, 0, 30],
        ),
      );
      await _pump(tester, api);
      expect(find.text('No matching reviews'), findsOneWidget);
      expect(
        find.text('Show all'),
        findsNothing,
        reason: 'nothing to reset yet',
      );

      await tester.tap(find.widgetWithText(FactoryChip, '3'));
      await tester.pumpAndSettle();
      expect(api.calls.last.rating, 3);
      expect(find.text('Show all'), findsOneWidget);

      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      expect(api.calls.last.rating, isNull);
    },
  );

  testWidgets('renders in Russian and Kazakh without overflow at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final code in ['ru', 'kk']) {
      final api = _FakeApi(
        summary: const ReviewSummary(
          average: 4.8,
          total: 128,
          distribution: [1, 0, 3, 20, 104],
        ),
        reviews: [
          _review(
            'r1',
            comment: 'Очень понравилось, спасибо большое!',
            reply: 'Спасибо!',
          ),
        ],
      );
      await _pump(tester, api, locale: Locale(code));
      expect(tester.takeException(), isNull);
    }
  });
}
