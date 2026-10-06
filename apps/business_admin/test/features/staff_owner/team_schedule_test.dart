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

WorkerSummary _worker(String id, String name, {bool configured = false, DateTime? offUntil, String kind = 'MASTER'}) =>
    WorkerSummary(
      id: id,
      kind: kind,
      displayName: name,
      photoUrl: null,
      active: true,
      scheduleConfigured: configured,
      offUntil: offUntil,
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

Widget _wrap(_FakeApi api, Widget home) => ProviderScope(
      overrides: [staffOwnerApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: factoryLightTheme(profile: FactoryAppProfile.business),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
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
