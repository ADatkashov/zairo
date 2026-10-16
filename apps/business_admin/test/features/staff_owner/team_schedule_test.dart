import 'package:business_admin/features/reviews/data/api/reviews_api.dart';
import 'package:business_admin/features/reviews/presentation/providers/reviews_providers.dart';
import 'package:business_admin/features/staff_owner/data/models/needs_attention.dart';
import 'package:business_admin/features/staff_owner/data/models/worker_schedule.dart';
import 'package:business_admin/features/staff_owner/data/staff_owner_api.dart';
import 'package:business_admin/features/staff_owner/presentation/providers/staff_owner_providers.dart';
import 'package:business_admin/features/staff_owner/presentation/screens/team_schedule_screen.dart';
import 'package:business_admin/features/staff_owner/presentation/screens/worker_schedule_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

WorkerSummary _worker(
  String id,
  String name, {
  bool configured = false,
  DateTime? offUntil,
  String kind = 'MASTER',
  double? rating,
  int reviews = 0,
}) =>
    WorkerSummary(
      id: id,
      kind: kind,
      displayName: name,
      photoUrl: null,
      active: true,
      scheduleConfigured: configured,
      offUntil: offUntil,
      averageRating: rating,
      reviewCount: reviews,
    );

class _FakeApi extends StaffOwnerApi {
  _FakeApi(this.workerList) : super(DioClient(Dio()));

  final List<WorkerSummary> workerList;
  bool allowChoice = true;
  final List<bool> choiceUpdates = [];
  List<HoursInterval>? savedHours;
  int? savedSlot;
  DateTime? timeOffFrom;
  DateTime? timeOffTo;
  int affected = 0;

  @override
  Future<List<WorkerSummary>> workers(String providerId) async => workerList;

  WorkerRating rating = const WorkerRating(averageRating: null, reviewCount: 0, distribution: [0, 0, 0, 0, 0], reviews: []);
  bool ratingFails = false;

  @override
  Future<WorkerRating> workerRating(String providerId, String workerId) async {
    if (ratingFails) throw Exception('offline');
    return rating;
  }

  @override
  Future<WorkforceSettings> settings(String providerId) async =>
      WorkforceSettings(allowWorkerChoice: allowChoice, workerPricingEnabled: false);

  @override
  Future<WorkforceSettings> updateSettings(
    String providerId, {
    required bool allowWorkerChoice,
    required bool workerPricingEnabled,
  }) async {
    allowChoice = allowWorkerChoice;
    choiceUpdates.add(allowWorkerChoice);
    return WorkforceSettings(allowWorkerChoice: allowWorkerChoice, workerPricingEnabled: workerPricingEnabled);
  }

  @override
  Future<WorkerScheduleData> schedule(String providerId, String workerId) async => const WorkerScheduleData(
        configured: false,
        zoneId: null,
        slotMinutes: 60,
        breakMinutes: 0,
        hours: [],
      );

  @override
  Future<SaveScheduleResult> saveSchedule(
    String providerId,
    String workerId, {
    required int slotMinutes,
    required int breakMinutes,
    required List<HoursInterval> hours,
  }) async {
    savedHours = hours;
    savedSlot = slotMinutes;
    return SaveScheduleResult(
      schedule: WorkerScheduleData(
        configured: true,
        zoneId: '+00:00',
        slotMinutes: slotMinutes,
        breakMinutes: breakMinutes,
        hours: hours,
      ),
      slotsCreated: 12,
      slotsRemoved: 0,
    );
  }

  @override
  Future<List<TimeOffItem>> timeOff(String providerId, String workerId) async => const [];

  @override
  Future<TimeOffCreated> createTimeOff(
    String providerId,
    String workerId, {
    required DateTime startsAt,
    required DateTime endsAt,
    String? reason,
  }) async {
    timeOffFrom = startsAt;
    timeOffTo = endsAt;
    return TimeOffCreated(
      timeOff: TimeOffItem(id: 't1', startsAt: startsAt, endsAt: endsAt, reason: reason, byWorker: false),
      affectedAppointments: affected,
    );
  }

  @override
  Future<List<NeedsAttentionItem>> needsAttention(String providerId) async => const [];
}

/// Records the owner's replies; saving one also puts it on the review the rating page reloads.
class _FakeReviewsApi extends ReviewsApi {
  _FakeReviewsApi(this.staffApi) : super(DioClient(Dio()));

  final _FakeApi staffApi;
  final List<({String reviewId, String reply})> replies = [];

  @override
  Future<({String reply, DateTime repliedAt})> replyToReview(String reviewId, String reply) async {
    replies.add((reviewId: reviewId, reply: reply));
    final current = staffApi.rating;
    staffApi.rating = WorkerRating(
      averageRating: current.averageRating,
      reviewCount: current.reviewCount,
      distribution: current.distribution,
      reviews: [
        for (final r in current.reviews)
          WorkerReviewItem(
            reviewId: r.reviewId,
            customerName: r.customerName,
            rating: r.rating,
            comment: r.comment,
            createdAt: r.createdAt,
            businessReply: r.reviewId == reviewId ? reply : r.businessReply,
          ),
      ],
    );
    return (reply: reply, repliedAt: DateTime(2026, 10, 13));
  }
}

Widget _wrap(_FakeApi api, Widget home, {ReviewsApi? reviewsApi}) => ProviderScope(
      overrides: [
        staffOwnerApiProvider.overrideWithValue(api),
        if (reviewsApi != null) reviewsApiProvider.overrideWithValue(reviewsApi),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(profile: FactoryAppProfile.business),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  testWidgets('the star on a person opens their rating: average, distribution and reviews with names', (tester) async {
    final api = _FakeApi([_worker('w1', 'Aigerim', rating: 4.5, reviews: 2)])
      ..rating = WorkerRating(
        averageRating: 4.5,
        reviewCount: 2,
        distribution: const [0, 0, 0, 1, 1],
        reviews: [
          WorkerReviewItem(
            reviewId: 'r1',
            customerName: 'Aisha K.',
            rating: 5,
            comment: 'Lovely work',
            createdAt: DateTime(2026, 10, 12),
            businessReply: 'Thanks!',
          ),
        ],
      );
    await tester.pumpWidget(_wrap(api, const TeamScheduleScreen(providerId: 'p1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rating and reviews'));
    await tester.pumpAndSettle();

    expect(find.text('4.5'), findsWidgets);
    expect(find.text('(2)'), findsWidgets);
    expect(find.text('1 more review to be among the best masters'), findsWidgets);
    expect(find.text('Latest reviews'), findsOneWidget);
    expect(find.text('Aisha K.'), findsOneWidget);
    expect(find.text('Lovely work'), findsOneWidget);
    expect(find.text('Reply from the business'), findsOneWidget);
    expect(find.text('Thanks!'), findsOneWidget);
    expect(find.text('Oct 12, 2026'), findsOneWidget);
  });

  testWidgets('the owner answers a review from the rating page, and edits an answer already given', (tester) async {
    WorkerReviewItem review(String id, String name, {String? reply}) => WorkerReviewItem(
          reviewId: id,
          customerName: name,
          rating: 5,
          comment: 'Great',
          createdAt: DateTime(2026, 10, 12),
          businessReply: reply,
        );
    final api = _FakeApi([_worker('w1', 'Aigerim', rating: 5, reviews: 2)])
      ..rating = WorkerRating(
        averageRating: 5,
        reviewCount: 2,
        distribution: const [0, 0, 0, 0, 2],
        reviews: [review('r1', 'Aisha K.'), review('r2', 'Dana S.', reply: 'Thank you!')],
      );
    final reviews = _FakeReviewsApi(api);
    await tester.pumpWidget(_wrap(api, const TeamScheduleScreen(providerId: 'p1'), reviewsApi: reviews));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rating and reviews'));
    await tester.pumpAndSettle();

    // One review has no answer yet ("Reply"), the other can be edited ("Edit reply").
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Edit reply'), findsOneWidget);

    await tester.ensureVisible(find.text('Reply'));
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Thank you, Aisha!');
    await tester.tap(find.text('Post reply'));
    await tester.pumpAndSettle();

    expect(reviews.replies, [(reviewId: 'r1', reply: 'Thank you, Aisha!')]);
    // The page reloaded: both reviews now carry an answer.
    expect(find.text('Thank you, Aisha!'), findsOneWidget);
    expect(find.text('Reply'), findsNothing);
    expect(find.text('Edit reply'), findsNWidgets(2));
  });

  testWidgets('cancelling the reply dialog changes nothing', (tester) async {
    final api = _FakeApi([_worker('w1', 'Aigerim', rating: 5, reviews: 1)])
      ..rating = WorkerRating(
        averageRating: 5,
        reviewCount: 1,
        distribution: const [0, 0, 0, 0, 1],
        reviews: [
          WorkerReviewItem(
            reviewId: 'r1',
            customerName: 'Aisha K.',
            rating: 5,
            comment: 'Great',
            createdAt: DateTime(2026, 10, 12),
            businessReply: null,
          ),
        ],
      );
    final reviews = _FakeReviewsApi(api);
    await tester.pumpWidget(_wrap(api, const TeamScheduleScreen(providerId: 'p1'), reviewsApi: reviews));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rating and reviews'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reply'));
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(reviews.replies, isEmpty);
    expect(find.text('Reply'), findsOneWidget);
  });

  testWidgets('a person with no reviews shows the empty state and what it takes', (tester) async {
    final api = _FakeApi([_worker('w1', 'Aigerim')]);
    await tester.pumpWidget(_wrap(api, const TeamScheduleScreen(providerId: 'p1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rating and reviews'));
    await tester.pumpAndSettle();

    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.text('No reviews yet · 3 reviews put them among the best masters'), findsWidgets);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    final api = _FakeApi([_worker('w1', 'Aigerim')])..ratingFails = true;
    await tester.pumpWidget(_wrap(api, const TeamScheduleScreen(providerId: 'p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rating and reviews'));
    await tester.pumpAndSettle();
    expect(find.byType(FactoryErrorState), findsOneWidget);

    api.ratingFails = false;
    await tester.tap(find.byType(FactoryButton));
    await tester.pumpAndSettle();

    expect(find.byType(FactoryErrorState), findsNothing);
  });

  testWidgets('each person shows their rating and how far they are from the best masters list', (tester) async {
    final api = _FakeApi([
      _worker('w1', 'Aigerim', rating: 4.8, reviews: 5),
      _worker('w2', 'Dana', rating: 5, reviews: 1),
      _worker('w3', 'Eldar'),
    ]);
    await tester.pumpWidget(_wrap(api, const TeamScheduleScreen(providerId: 'p1')));
    await tester.pumpAndSettle();

    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Eligible for the best masters list'), findsOneWidget);
    expect(find.text('2 more reviews to be among the best masters'), findsOneWidget);
    expect(find.text('No reviews yet · 3 reviews put them among the best masters'), findsOneWidget);
  });

  testWidgets('one review short reads in the singular', (tester) async {
    final api = _FakeApi([_worker('w1', 'Aigerim', rating: 4, reviews: 2)]);
    await tester.pumpWidget(_wrap(api, const TeamScheduleScreen(providerId: 'p1')));
    await tester.pumpAndSettle();

    expect(find.text('1 more review to be among the best masters'), findsOneWidget);
  });

  test('WorkerSummary reads the rating, and its absence', () {
    final base = {
      'id': 'w1',
      'kind': 'MASTER',
      'displayName': 'A',
      'photoUrl': null,
      'active': true,
      'scheduleConfigured': false,
      'offUntil': null,
    };
    final rated = WorkerSummary.fromJson({...base, 'averageRating': 4.5, 'reviewCount': 2});
    expect(rated.averageRating, 4.5);
    expect(rated.reviewCount, 2);
    final unrated = WorkerSummary.fromJson(base);
    expect(unrated.averageRating, isNull);
    expect(unrated.reviewCount, 0);
  });

  testWidgets('lists the team with who has their own schedule, and the choice switch updates the setting', (
    tester,
  ) async {
    final api = _FakeApi([
      _worker('w1', 'Aigerim', configured: true),
      _worker('w2', 'Dana', offUntil: DateTime.now().add(const Duration(days: 1))),
    ]);
    await tester.pumpWidget(_wrap(api, const TeamScheduleScreen(providerId: 'p1')));
    await tester.pumpAndSettle();

    expect(find.text('Aigerim'), findsOneWidget);
    expect(find.text('Own schedule'), findsOneWidget);
    expect(find.text('Shared times'), findsOneWidget);
    expect(find.textContaining('Not in until'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(api.choiceUpdates, [false]);
  });

  testWidgets('a new schedule starts as Mon-Fri 9-18 and saves exactly the hours shown', (tester) async {
    final api = _FakeApi([_worker('w1', 'Aigerim')]);
    await tester.pumpWidget(_wrap(
      api,
      WorkerScheduleScreen(providerId: 'p1', worker: _worker('w1', 'Aigerim')),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Save schedule'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(api.savedSlot, 60);
    expect(api.savedHours, isNotNull);
    expect(api.savedHours!.map((h) => h.dayOfWeek), [1, 2, 3, 4, 5]);
    expect(api.savedHours!.first.start, const TimeOfDay(hour: 9, minute: 0));
    expect(api.savedHours!.first.end, const TimeOfDay(hour: 18, minute: 0));
    expect(find.textContaining('12 times added'), findsOneWidget);
  });

  testWidgets('removing a day\'s hours makes it a day off in what is saved', (tester) async {
    final api = _FakeApi([_worker('w1', 'Aigerim')]);
    await tester.pumpWidget(_wrap(
      api,
      WorkerScheduleScreen(providerId: 'p1', worker: _worker('w1', 'Aigerim')),
    ));
    await tester.pumpAndSettle();

    // Delete Monday's interval via the chip's delete icon.
    final monday = find.byKey(const ValueKey('interval-1-0'));
    await tester.tap(find.descendant(of: monday, matching: find.byType(Icon)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Save schedule'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(api.savedHours!.map((h) => h.dayOfWeek), [2, 3, 4, 5]);
  });

  testWidgets('"Not in today" records time off from now and says how many bookings need a decision', (tester) async {
    final api = _FakeApi([_worker('w1', 'Aigerim')])..affected = 2;
    await tester.pumpWidget(_wrap(
      api,
      WorkerScheduleScreen(providerId: 'p1', worker: _worker('w1', 'Aigerim')),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Not in today'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Not in today'));
    await tester.pumpAndSettle();

    expect(api.timeOffFrom, isNotNull);
    expect(api.timeOffTo!.isAfter(api.timeOffFrom!), isTrue);
    expect(find.textContaining('2 booked appointment'), findsOneWidget);
  });

  test('the zone offset sent to the server is a valid fixed offset', () {
    expect(StaffOwnerApi.localZoneOffset(const Duration(hours: 6)), '+06:00');
    expect(StaffOwnerApi.localZoneOffset(const Duration(hours: -3, minutes: -30)), '-03:30');
    expect(StaffOwnerApi.localZoneOffset(Duration.zero), '+00:00');
  });
}
