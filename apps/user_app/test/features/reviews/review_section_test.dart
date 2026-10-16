import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:zairo/features/reviews/data/models/review.dart';
import 'package:zairo/features/workers/data/models/booking_worker.dart';
import 'package:zairo/features/workers/data/workers_api.dart';
import 'package:zairo/features/workers/presentation/providers/workers_providers.dart';
import 'package:zairo/features/reviews/data/review_exception.dart';
import 'package:zairo/features/reviews/data/reviews_api.dart';
import 'package:zairo/features/reviews/presentation/providers/reviews_providers.dart';
import 'package:zairo/features/reviews/presentation/widgets/review_section.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeReviewsApi extends ReviewsApi {
  _FakeReviewsApi({Review? existing})
    : _review = existing,
      super(DioClient(Dio()));

  Review? _review;
  Map<String, dynamic>? lastCreateCall;
  Object? errorOnCreate;

  @override
  Future<Review?> getReview(String bookingId) async => _review;

  @override
  Future<Review> createReview({
    required String bookingId,
    required int rating,
    String? comment,
    int? workerRating,
  }) async {
    if (errorOnCreate != null) throw errorOnCreate!;
    lastCreateCall = {
      'bookingId': bookingId,
      'rating': rating,
      'comment': comment,
      'workerRating': workerRating,
    };
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

class _FakeWorkersApi extends WorkersApi {
  _FakeWorkersApi({this.worker}) : super(DioClient(Dio()));

  final BookingWorker? worker;

  @override
  Future<BookingWorker> getBookingWorker(String bookingId) async {
    if (worker == null) throw Exception('404');
    return worker!;
  }
}

void main() {
  late _FakeReviewsApi reviewsApi;

  Future<void> openDialog(WidgetTester tester, BookingWorker? worker) async {
    reviewsApi = _FakeReviewsApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewsApiProvider.overrideWithValue(reviewsApi),
          workersApiProvider.overrideWithValue(_FakeWorkersApi(worker: worker)),
        ],
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
  }

  testWidgets('the review dialog names the person the visit was with', (tester) async {
    await openDialog(tester, const BookingWorker(id: 'w1', kind: 'MASTER', displayName: 'Aigerim'));

    expect(find.text('Your visit with Aigerim'), findsOneWidget);
  });

  const aigerim = BookingWorker(id: 'w1', kind: 'MASTER', displayName: 'Aigerim');

  testWidgets('with a named person there is a second, optional row of stars for them', (tester) async {
    await openDialog(tester, aigerim);

    expect(find.text('The business'), findsOneWidget);
    expect(find.text('Aigerim'), findsOneWidget);
    expect(find.text('Optional. Without it, your rating above counts for Aigerim too.'), findsOneWidget);
    // Two rows of five stars.
    expect(find.byTooltip('Rate 3 stars'), findsNWidgets(2));
  });

  testWidgets('rating the business alone sends one rating; the person is not rated apart', (tester) async {
    await openDialog(tester, aigerim);

    await tester.tap(find.byTooltip('Rate 5 stars').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(reviewsApi.lastCreateCall?['rating'], 5);
    expect(reviewsApi.lastCreateCall?['workerRating'], isNull);
  });

  testWidgets('rating the person apart sends both marks', (tester) async {
    await openDialog(tester, aigerim);

    await tester.tap(find.byTooltip('Rate 5 stars').first);
    await tester.tap(find.byTooltip('Rate 3 stars').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(reviewsApi.lastCreateCall?['rating'], 5);
    expect(reviewsApi.lastCreateCall?['workerRating'], 3);
  });

  testWidgets('without a named person the dialog just asks for the rating', (tester) async {
    await openDialog(tester, null);

    expect(find.textContaining('Your visit with'), findsNothing);
    expect(find.byIcon(Symbols.star_rounded), findsWidgets);
    expect(find.byTooltip('Rate 3 stars'), findsOneWidget);
    expect(find.text('The business'), findsNothing);
  });

  testWidgets('shows a "leave a review" button when there is no review yet', (
    tester,
  ) async {
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

  testWidgets('shows the existing review instead of the button', (
    tester,
  ) async {
    final existing = Review(
      id: 'review-1',
      bookingId: 'booking-1',
      rating: 4,
      comment: 'Great service',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewsApiProvider.overrideWithValue(
            _FakeReviewsApi(existing: existing),
          ),
        ],
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
    // Symbols.star_rounded is one IconData regardless of fill state — solid
    // vs outline is the Icon widget's `fill` value, not a different icon
    // identity the way classic Icons.star/star_border were.
    final stars = tester.widgetList<Icon>(find.byIcon(Symbols.star_rounded));
    expect(stars.where((icon) => icon.fill == 1), hasLength(4));
    expect(stars.where((icon) => icon.fill == 0), hasLength(1));
  });

  testWidgets(
    'submitting a review from the dialog calls the API with the picked rating',
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

      // Tap the 4th star icon button to set rating = 4. Scoped to the dialog:
      // the "Leave a review" button underneath (still mounted, just obscured
      // by the modal barrier) uses this exact same Symbols.star_rounded
      // IconData too, so an unscoped find.byIcon would match 6, not 5.
      expect(find.byTooltip('Rate 4 stars'), findsOneWidget);
      final starButtons = find.descendant(
        of: find.byType(FactoryDialog),
        matching: find.byIcon(Symbols.star_rounded),
      );
      await tester.tap(starButtons.at(3));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Loved it');
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(fakeApi.lastCreateCall, {
        'bookingId': 'booking-1',
        'rating': 4,
        'comment': 'Loved it',
        'workerRating': null,
      });
      // Dialog closes and the section now shows the submitted review.
      expect(find.text('Loved it'), findsOneWidget);
    },
  );

  testWidgets('shows a readable error when submission fails', (tester) async {
    final fakeApi = _FakeReviewsApi()
      ..errorOnCreate = const ReviewException(
        ReviewErrorKey.duplicateOrNotCompleted,
      );

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
    await tester.tap(
      find
          .descendant(
            of: find.byType(FactoryDialog),
            matching: find.byIcon(Symbols.star_rounded),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(
      find.text('This booking already has a review, or is not completed yet.'),
      findsOneWidget,
    );
  });
}
