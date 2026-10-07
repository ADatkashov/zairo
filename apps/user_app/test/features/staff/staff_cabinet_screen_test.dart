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

StaffMembership _membership(String id, String business, {int pending = 0}) => StaffMembership(
      staffId: id,
      providerId: 'p-$id',
      providerName: business,
      displayName: 'Aigerim',
      photoUrl: null,
      active: true,
      pendingCount: pending,
      averageRating: 4.5,
      reviewCount: 2,
    );

StaffAppointment _appointment(String id, {bool canAccept = true}) => StaffAppointment(
      bookingId: id,
      status: 'CONFIRMED',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      endsAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
      serviceTitle: 'Haircut',
      customerName: 'Dana',
      customerPhone: null,
      totalPrice: 25,
      currency: 'USD',
      paidAmount: 25,
      cancellationReason: null,
      staffConfirmedAt: null,
      staffDeclinedAt: null,
      canAccept: canAccept,
      canDecline: true,
      canComplete: true,
      canMarkNoShow: true,
    );

class _FakeCabinetApi extends StaffCabinetApi {
  _FakeCabinetApi(this._memberships, this._appointmentsByStaff) : super(DioClient(Dio()));

  final List<StaffMembership> _memberships;
  final Map<String, List<StaffAppointment>> _appointmentsByStaff;
  final List<String> accepted = [];
  final List<String> declined = [];

  @override
  Future<List<StaffMembership>> memberships() async => _memberships;

  @override
  Future<List<StaffAppointment>> appointments(String staffId, {String scope = 'ALL'}) async =>
      _appointmentsByStaff[staffId] ?? const [];

  @override
  Future<void> accept(String staffId, String bookingId) async => accepted.add('$staffId/$bookingId');

  @override
  Future<void> cannotAttend(String staffId, String bookingId, {String? reason}) async =>
      declined.add('$staffId/$bookingId');

  @override
  Future<StaffRating> rating(String staffId) async =>
      const StaffRating(averageRating: null, reviewCount: 0, distribution: [0, 0, 0, 0, 0], reviews: []);
}

Widget _wrap(_FakeCabinetApi api) => ProviderScope(
      overrides: [staffCabinetApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StaffCabinetScreen(),
      ),
    );

void main() {
  testWidgets('switching business shows only that business\'s appointments', (tester) async {
    final api = _FakeCabinetApi(
      [_membership('s1', 'Salon One', pending: 1), _membership('s2', 'Salon Two')],
      {
        's1': [_appointment('b1')],
        's2': const [],
      },
    );
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    expect(find.text('Haircut'), findsOneWidget);

    await tester.tap(find.text('Salon Two'));
    await tester.pumpAndSettle();

    expect(find.text('Haircut'), findsNothing);
    expect(find.text('No upcoming appointments'), findsOneWidget);
  });

  testWidgets('accepting an appointment calls the API for that staff profile', (tester) async {
    final api = _FakeCabinetApi(
      [_membership('s1', 'Salon One', pending: 1)],
      {
        's1': [_appointment('b1')],
      },
    );
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(api.accepted, ['s1/b1']);
  });

  testWidgets('"Can\'t attend" asks the owner instead of cancelling', (tester) async {
    final api = _FakeCabinetApi(
      [_membership('s1', 'Salon One', pending: 1)],
      {
        's1': [_appointment('b1')],
      },
    );
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    // There is no cancel action for staff at all.
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text("Can't attend"));
    await tester.pumpAndSettle();
    expect(find.text("Can't attend this appointment?"), findsOneWidget);

    await tester.tap(find.text('Tell the owner'));
    await tester.pumpAndSettle();

    expect(api.declined, ['s1/b1']);
  });
}
