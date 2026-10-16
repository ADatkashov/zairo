import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/staff/data/models/staff_cabinet.dart';
import 'package:zairo/features/staff/data/staff_cabinet_api.dart';
import 'package:zairo/features/staff/presentation/providers/staff_cabinet_providers.dart';
import 'package:zairo/features/staff/presentation/screens/staff_cabinet_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

StaffMembership _membership({bool active = true}) => StaffMembership(
  staffId: 's1',
  providerId: 'p1',
  providerName: 'Salon One',
  displayName: 'Aigerim',
  photoUrl: null,
  active: active,
  pendingCount: 0,
  averageRating: 4.5,
  reviewCount: 2,
);

StaffAppointment _appointment(
  String id, {
  String status = 'CONFIRMED',
  Duration startsIn = const Duration(days: 1),
  bool canAccept = false,
  bool canDecline = false,
  bool canComplete = false,
  bool canMarkNoShow = false,
  String? customerName = 'Dana',
  String? customerPhone,
  String? cancellationReason,
  DateTime? confirmedAt,
  DateTime? declinedAt,
}) => StaffAppointment(
  bookingId: id,
  status: status,
  startsAt: DateTime.now().add(startsIn),
  endsAt: DateTime.now().add(startsIn + const Duration(hours: 1)),
  serviceTitle: 'Haircut $id',
  customerName: customerName,
  customerPhone: customerPhone,
  totalPrice: 25,
  currency: 'USD',
  paidAmount: 25,
  cancellationReason: cancellationReason,
  staffConfirmedAt: confirmedAt,
  staffDeclinedAt: declinedAt,
  canAccept: canAccept,
  canDecline: canDecline,
  canComplete: canComplete,
  canMarkNoShow: canMarkNoShow,
);

class _Api extends StaffCabinetApi {
  _Api({
    this.memberships_ = const [],
    this.items = const [],
    this.rating_,
    this.failMemberships = false,
    this.failRating = false,
  }) : super(DioClient(Dio()));

  final List<StaffMembership> memberships_;
  final List<StaffAppointment> items;
  final StaffRating? rating_;
  bool failMemberships;
  bool failAction = false;
  bool failRating;
  final List<String> calls = [];
  int membershipLoads = 0;
  int ratingLoads = 0;

  @override
  Future<List<StaffMembership>> memberships() async {
    membershipLoads++;
    if (failMemberships) throw Exception('down');
    return memberships_;
  }

  @override
  Future<List<StaffAppointment>> appointments(
    String staffId, {
    String scope = 'ALL',
  }) async => items;

  @override
  Future<void> complete(String staffId, String bookingId) async {
    if (failAction) throw Exception('nope');
    calls.add('complete $bookingId');
  }

  @override
  Future<void> markNoShow(String staffId, String bookingId) async {
    if (failAction) throw Exception('nope');
    calls.add('noshow $bookingId');
  }

  @override
  Future<void> cannotAttend(
    String staffId,
    String bookingId, {
    String? reason,
  }) async {
    calls.add('decline $bookingId');
  }

  @override
  Future<StaffRating> rating(String staffId) async {
    ratingLoads++;
    if (failRating) throw Exception('down');
    return rating_ ??
        const StaffRating(
          averageRating: null,
          reviewCount: 0,
          distribution: [0, 0, 0, 0, 0],
          reviews: [],
        );
  }
}

Widget _wrap(_Api api) => ProviderScope(
  retry: (_, _) => null,
  overrides: [staffCabinetApiProvider.overrideWithValue(api)],
  child: MaterialApp(
    theme: factoryLightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const StaffCabinetScreen(),
  ),
);

Future<void> _open(WidgetTester tester, _Api api) async {
  await tester.pumpWidget(_wrap(api));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a person with no staff profile sees the empty state', (
    tester,
  ) async {
    await _open(tester, _Api());
    expect(find.text('No upcoming appointments'), findsOneWidget);
  });

  testWidgets('a failed load shows an error and Retry loads again', (
    tester,
  ) async {
    final api = _Api(memberships_: [_membership()], failMemberships: true);
    await _open(tester, api);
    expect(find.text("Couldn't load your appointments."), findsOneWidget);

    api.failMemberships = false;
    await tester.tap(find.byType(FactoryButton));
    await tester.pumpAndSettle();

    expect(find.text('Salon One'), findsWidgets);
    expect(api.membershipLoads, 2);
  });

  testWidgets('a deactivated profile says so and offers no actions to press', (
    tester,
  ) async {
    final api = _Api(
      memberships_: [_membership(active: false)],
      items: [
        _appointment(
          'b1',
          canComplete: true,
          startsIn: const Duration(minutes: 30),
        ),
      ],
    );
    await _open(tester, api);

    expect(find.textContaining('deactivated'), findsOneWidget);
    await tester.tap(find.text('Complete'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
  });

  testWidgets(
    'Complete, No-show (after confirming) and Decline (keep) call the right actions',
    (tester) async {
      final api = _Api(
        memberships_: [_membership()],
        items: [
          _appointment(
            'b1',
            canComplete: true,
            canMarkNoShow: true,
            canDecline: true,
          ),
        ],
      );
      await _open(tester, api);

      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      expect(api.calls, ['complete b1']);

      await tester.tap(find.text('No-show'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as no-show?'), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(api.calls, ['complete b1']);

      await tester.tap(find.text('No-show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark no-show'));
      await tester.pumpAndSettle();
      expect(api.calls, ['complete b1', 'noshow b1']);

      await tester.tap(find.text("Can't attend"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(api.calls, ['complete b1', 'noshow b1']);
    },
  );

  testWidgets('a failed action says so and the card stays usable', (
    tester,
  ) async {
    final api = _Api(
      memberships_: [_membership()],
      items: [_appointment('b1', canComplete: true)],
    )..failAction = true;
    await _open(tester, api);

    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't update the appointment. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Complete'), findsOneWidget);
  });

  testWidgets(
    'cards say who, how to reach them, and where the appointment stands',
    (tester) async {
      final api = _Api(
        memberships_: [_membership()],
        items: [
          _appointment('awaiting', customerPhone: '+77001234567'),
          _appointment('accepted', confirmedAt: DateTime.now()),
          _appointment(
            'declined',
            declinedAt: DateTime.now(),
            customerName: null,
          ),
          _appointment('unpaid', status: 'PENDING_PAYMENT'),
        ],
      );
      await _open(tester, api);

      expect(find.text('Dana · +77001234567'), findsOneWidget);
      expect(find.text('Needs your confirmation'), findsOneWidget);
      expect(find.text('Accepted by you'), findsOneWidget);
      expect(find.text('Sent to the owner'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('25.00 USD'), findsWidgets);
    },
  );

  testWidgets(
    'History lists past and cancelled visits with their status and reason',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _Api(
        memberships_: [_membership()],
        items: [
          _appointment(
            'done',
            status: 'COMPLETED',
            startsIn: const Duration(days: -2),
          ),
          _appointment(
            'gone',
            status: 'CANCELLED',
            startsIn: const Duration(days: -1),
            cancellationReason: 'Ill',
          ),
          _appointment(
            'missed',
            status: 'NO_SHOW',
            startsIn: const Duration(days: -3),
          ),
          _appointment(
            'odd',
            status: 'WEIRD',
            startsIn: const Duration(days: -4),
          ),
        ],
      );
      await _open(tester, api);
      expect(find.text('No upcoming appointments'), findsOneWidget);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Ill'), findsOneWidget);
      expect(find.text('WEIRD'), findsOneWidget);
      expect(find.text('Haircut done'), findsOneWidget);
    },
  );

  testWidgets('History says so when there is nothing yet', (tester) async {
    await _open(tester, _Api(memberships_: [_membership()]));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No past appointments yet'), findsOneWidget);
  });

  testWidgets('Rating: no reviews yet', (tester) async {
    await _open(tester, _Api(memberships_: [_membership()]));
    await tester.tap(find.text('Rating'));
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet'), findsOneWidget);
  });

  testWidgets(
    'Rating: the average, the stars distribution and each review with its reply',
    (tester) async {
      final api = _Api(
        memberships_: [_membership()],
        rating_: StaffRating(
          averageRating: 4.5,
          reviewCount: 2,
          distribution: const [0, 0, 0, 1, 1],
          reviews: [
            StaffReview(
              reviewId: 'r1',
              bookingId: 'b1',
              customerName: 'Dana',
              rating: 5,
              comment: 'Lovely',
              createdAt: DateTime(2026, 10, 1, 12),
              businessReply: 'Thank you',
            ),
            StaffReview(
              reviewId: 'r2',
              bookingId: 'b2',
              customerName: null,
              rating: 4,
              comment: null,
              createdAt: DateTime(2026, 10, 2, 12),
              businessReply: null,
            ),
          ],
        ),
      );
      await _open(tester, api);
      await tester.tap(find.text('Rating'));
      await tester.pumpAndSettle();

      expect(find.text('4.5'), findsWidgets);
      expect(find.text('Lovely'), findsOneWidget);
      expect(find.text('Business reply: Thank you'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
    },
  );

  testWidgets('Rating: a failed load can be retried', (tester) async {
    final api = _Api(memberships_: [_membership()], failRating: true);
    await _open(tester, api);
    await tester.tap(find.text('Rating'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your appointments."), findsOneWidget);

    api.failRating = false;
    await tester.tap(find.byType(FactoryButton));
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet'), findsOneWidget);
    expect(api.ratingLoads, 2);
  });

  testWidgets(
    'the cabinet fits a 320 px phone with a large font in the dark theme',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _Api(
        memberships_: [_membership()],
        items: [
          _appointment(
            'b1',
            canAccept: true,
            canComplete: true,
            canMarkNoShow: true,
            canDecline: true,
            customerPhone: '+77001234567',
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [staffCabinetApiProvider.overrideWithValue(api)],
          child: MaterialApp(
            theme: factoryDarkTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const StaffCabinetScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
