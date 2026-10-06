import 'package:business_admin/features/loyalty/data/models/loyalty_page.dart';
import 'package:business_admin/features/reviews/data/api/reviews_api.dart';
import 'package:business_admin/features/reviews/data/models/provider_review.dart';
import 'package:business_admin/features/reviews/presentation/providers/reviews_providers.dart';
import 'package:business_admin/features/reviews/presentation/screens/reviews_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReviewsApi extends ReviewsApi {
  _FakeReviewsApi(this._reviews) : super(DioClient(Dio()));

  final List<ProviderReview> _reviews;

  @override
  Future<LoyaltyPage<ProviderReview>> fetchReviews(String providerId, {int page = 0, int size = 20}) async =>
      LoyaltyPage(
        content: _reviews,
        totalElements: _reviews.length,
        totalPages: 1,
        number: 0,
        size: size,
        first: true,
        last: true,
      );
}

ProviderReview _review(String id, int rating, {String? reply}) => ProviderReview(
      id: id,
      bookingId: 'b-$id',
      customerName: 'Customer $id',
      rating: rating,
      comment: 'Comment $id',
      createdAt: DateTime(2026, 1, 1),
      businessReply: reply,
      businessReplyAt: reply == null ? null : DateTime(2026, 1, 2),
    );

Future<void> _pump(WidgetTester tester, List<ProviderReview> reviews, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reviewsApiProvider.overrideWithValue(_FakeReviewsApi(reviews))],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReviewsScreen(providerId: 'p-1', providerName: 'Zen Spa'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('summary shows the average, star distribution and the awaiting-reply count', (tester) async {
    await _pump(tester, [_review('1', 5), _review('2', 4, reply: 'Thanks'), _review('3', 5)], const Size(390, 800));

    expect(find.text('4.7'), findsOneWidget);
    // Two of three reviews have no reply yet.
    expect(find.text('2'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no summary while there are no reviews', (tester) async {
    await _pump(tester, const [], const Size(390, 800));

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('summary does not overflow on a narrow phone', (tester) async {
    await _pump(tester, [_review('1', 3)], const Size(320, 640));

    expect(tester.takeException(), isNull);
  });
}
