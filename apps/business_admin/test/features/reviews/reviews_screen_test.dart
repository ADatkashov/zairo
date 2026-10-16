import 'package:business_admin/features/loyalty/data/models/loyalty_page.dart';
import 'package:business_admin/features/reviews/data/api/reviews_api.dart';
import 'package:business_admin/features/reviews/data/models/provider_review.dart';
import 'package:business_admin/features/reviews/data/reviews_exception.dart';
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
  final List<({String reviewId, String reason})> reports = [];
  Object? reportError;

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

  @override
  Future<void> reportReview(String reviewId, String reason) async {
    reports.add((reviewId: reviewId, reason: reason));
    if (reportError != null) throw reportError!;
  }
}

ProviderReview _review(String id, int rating, {String? reply, String? moderation}) => ProviderReview(
  id: id,
  bookingId: 'b-$id',
  customerName: 'Customer $id',
  rating: rating,
  comment: 'Comment $id',
  createdAt: DateTime(2026, 1, 1),
  businessReply: reply,
  businessReplyAt: reply == null ? null : DateTime(2026, 1, 2),
  moderationStatus: moderation,
);

Future<void> _pump(
  WidgetTester tester,
  List<ProviderReview> reviews,
  Size size, {
  _FakeReviewsApi? api,
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reviewsApiProvider.overrideWithValue(api ?? _FakeReviewsApi(reviews))],
      child: MaterialApp(
        theme: dark ? factoryDarkTheme() : factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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

  testWidgets('a review can be reported once: the reason is asked for, sent, and the card then shows where it stands',
      (tester) async {
    final reviews = [_review('1', 1)];
    final api = _FakeReviewsApi(reviews);
    await _pump(tester, reviews, const Size(390, 900), api: api);

    await tester.tap(find.text('Report this review'));
    await tester.pumpAndSettle();
    // An empty reason is not sent.
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('Please say what is wrong with it.'), findsOneWidget);
    expect(api.reports, isEmpty);

    await tester.enterText(find.byType(TextField), 'Abusive language');
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(api.reports, [(reviewId: '1', reason: 'Abusive language')]);
    expect(find.text('Report this review'), findsNothing);
    expect(find.text('Reported — the platform is looking at it'), findsOneWidget);
  });

  testWidgets('cancelling the report dialog leaves the review as it was', (tester) async {
    final reviews = [_review('1', 1)];
    final api = _FakeReviewsApi(reviews);
    await _pump(tester, reviews, const Size(390, 900), api: api);

    await tester.tap(find.text('Report this review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(api.reports, isEmpty);
    expect(find.text('Report this review'), findsOneWidget);
  });

  testWidgets('a refused report says why in the dialog and can be retried', (tester) async {
    final reviews = [_review('1', 1)];
    final api = _FakeReviewsApi(reviews)..reportError = const ReviewsException(statusCode: 409);
    await _pump(tester, reviews, const Size(390, 900), api: api);

    await tester.tap(find.text('Report this review'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Abusive language');
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('This review was already reported.'), findsOneWidget);

    api.reportError = Exception('offline');
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('reviews already reported show their state instead of the report button', (tester) async {
    await _pump(
      tester,
      [_review('1', 1, moderation: 'OPEN'), _review('2', 1, moderation: 'HIDDEN'), _review('3', 1, moderation: 'DISMISSED')],
      const Size(390, 1800),
    );

    expect(find.text('Report this review'), findsNothing);
    expect(find.text('Reported — the platform is looking at it'), findsOneWidget);
    expect(find.text('Hidden by the platform — it no longer counts in your rating'), findsOneWidget);
    expect(find.text('The platform looked at it and kept it'), findsOneWidget);
  });

  testWidgets('review cards with report actions and statuses fit a 320 px phone with a large font in the dark theme', (
    tester,
  ) async {
    await _pump(
      tester,
      [
        _review('1', 1),
        _review('2', 2, reply: 'Thank you for telling us, we are sorry about this', moderation: 'OPEN'),
        _review('3', 3, moderation: 'HIDDEN'),
        _review('4', 4, moderation: 'DISMISSED'),
      ],
      const Size(320, 640),
      textScale: 2,
      dark: true,
    );

    // Walk down the list so every card is built at this size.
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('The platform looked at it and kept it'), findsOneWidget);
  });

  testWidgets('a new reply offers three ready sentences; tapping one fills the field, which stays editable', (tester) async {
    await _pump(tester, [_review('1', 5)], const Size(390, 1200));

    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(find.text('Thank you for your feedback!'), findsOneWidget);
    expect(find.text("We're glad you liked it. See you again soon!"), findsOneWidget);
    expect(find.textContaining("We're sorry about this"), findsOneWidget);

    await tester.tap(find.text('Thank you for your feedback!'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Thank you for your feedback!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Thank you, Aisha!');
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Thank you, Aisha!'), findsOneWidget);
  });

  testWidgets('editing an existing reply offers no templates', (tester) async {
    await _pump(tester, [_review('1', 5, reply: 'Already answered')], const Size(390, 1200));

    await tester.tap(find.text('Edit reply'));
    await tester.pumpAndSettle();

    expect(find.byType(ActionChip), findsNothing);
  });
}
