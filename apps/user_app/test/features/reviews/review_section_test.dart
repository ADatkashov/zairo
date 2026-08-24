import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/reviews/data/models/review.dart';
import 'package:zairo/features/reviews/data/review_exception.dart';
import 'package:zairo/features/reviews/data/reviews_api.dart';
import 'package:zairo/features/reviews/presentation/providers/reviews_providers.dart';
import 'package:zairo/features/reviews/presentation/widgets/review_section.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeReviewsApi extends ReviewsApi {
  _FakeReviewsApi({Review? existing}) : _review = existing, super(DioClient(Dio()));

  Review? _review;
  Map<String, dynamic>? lastCreateCall;
  Object? errorOnCreate;

  @override
  Future<Review?> getReview(String bookingId) async => _review;

  @override
  Future<Review> createReview({required String bookingId, required int rating, String? comment}) async {
    if (errorOnCreate != null) throw errorOnCreate!;
    lastCreateCall = {'bookingId': bookingId, 'rating': rating, 'comment': comment};
    _review = Review(
      id: 'review-1',
      bookingId: bookingId,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );
    return _review!;
  }
}

void main() {
  testWidgets('shows a "leave a review" button when there is no review yet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reviewsApiProvider.overrideWithValue(_FakeReviewsApi())],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ReviewSection(bookingId: 'booking-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leave a review'), findsOneWidget);
  });

  testWidgets('shows the existing review instead of the button', (tester) async {
    final existing = Review(
      id: 'review-1',
      bookingId: 'booking-1',
      rating: 4,
      comment: 'Great service',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reviewsApiProvider.overrideWithValue(_FakeReviewsApi(existing: existing))],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ReviewSection(bookingId: 'booking-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leave a review'), findsNothing);
    expect(find.text('Great service'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(4));
    expect(find.byIcon(Icons.star_border), findsNWidgets(1));
  });

  testWidgets('submitting a review from the dialog calls the API with the picked rating',
      (tester) async {
    final fakeApi = _FakeReviewsApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reviewsApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ReviewSection(bookingId: 'booking-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leave a review'));
    await tester.pumpAndSettle();

    // Tap the 4th star icon button to set rating = 4.
    expect(find.byTooltip('Rate 4 stars'), findsOneWidget);
    final starButtons = find.byIcon(Icons.star_border);
    await tester.tap(starButtons.at(3));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Loved it');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastCreateCall, {
      'bookingId': 'booking-1',
      'rating': 4,
      'comment': 'Loved it',
    });
    // Dialog closes and the section now shows the submitted review.
    expect(find.text('Loved it'), findsOneWidget);
  });

  testWidgets('shows a readable error when submission fails', (tester) async {
    final fakeApi = _FakeReviewsApi()
      ..errorOnCreate = const ReviewException(ReviewErrorKey.duplicateOrNotCompleted);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reviewsApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ReviewSection(bookingId: 'booking-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leave a review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(find.text('This booking already has a review, or is not completed yet.'), findsOneWidget);
  });
}
