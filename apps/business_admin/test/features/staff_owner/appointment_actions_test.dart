import 'package:business_admin/features/salon/data/models/schedule_entry.dart';
import 'package:business_admin/features/staff_owner/data/models/reschedule_option.dart';
import 'package:business_admin/features/staff_owner/data/staff_owner_api.dart';
import 'package:business_admin/features/staff_owner/presentation/providers/staff_owner_providers.dart';
import 'package:business_admin/features/staff_owner/presentation/widgets/appointment_actions.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends StaffOwnerApi {
  _FakeApi({this.options = const [], this.failMove = false}) : super(DioClient(Dio()));

  final List<RescheduleOption> options;
  final bool failMove;
  final List<String> calls = [];

  @override
  Future<List<RescheduleOption>> rescheduleOptions(String bookingId) async => options;

  @override
  Future<void> reschedule(String bookingId, String slotId) async {
    if (failMove) throw Exception('taken');
    calls.add('move $bookingId $slotId');
  }

  @override
  Future<void> markNoShow(String bookingId) async => calls.add('noshow $bookingId');

  @override
  Future<void> markCompleted(String bookingId) async => calls.add('complete $bookingId');
}

AgendaItem _item({required Duration startsIn, String status = 'CONFIRMED'}) {
  final start = DateTime.now().add(startsIn);
  return AgendaItem(
    entry: ScheduleEntry(
      bookingId: 'b1',
      serviceId: 's1',
      availabilitySlotId: 'slot',
      status: status,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
      totalPrice: 25,
    ),
    providerId: 'p1',
    providerName: 'Salon',
    serviceTitle: 'Haircut',
  );
}

Future<int> _pump(
  WidgetTester tester,
  _FakeApi api,
  AgendaItem item, {
  Size size = const Size(800, 1200),
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var changed = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [staffOwnerApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: dark
            ? factoryDarkTheme(profile: FactoryAppProfile.business)
            : factoryLightTheme(profile: FactoryAppProfile.business),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: AppointmentActions(item: item, onChanged: () => changed++, child: const Text('row')),
        ),
      ),
    ),
  );
  await tester.tap(find.text('row'));
  await tester.pumpAndSettle();
  return changed;
}

RescheduleOption _option(String id, DateTime start) =>
    RescheduleOption(slotId: id, startsAt: start, endsAt: start.add(const Duration(hours: 1)));

void main() {
  testWidgets('a future appointment can only be moved', (tester) async {
    await _pump(tester, _FakeApi(), _item(startsIn: const Duration(days: 1)));
    expect(find.text('Move to another time'), findsOneWidget);
    expect(find.text('Customer did not come'), findsNothing);
    expect(find.text('Visit done'), findsNothing);
  });

  testWidgets('moving: pick a free time, the customer is told and the agenda refreshes', (tester) async {
    final tomorrow = DateTime.now().add(const Duration(days: 2));
    final api = _FakeApi(options: [_option('s2', tomorrow), _option('s3', tomorrow.add(const Duration(hours: 2)))]);
    var changed = 0;
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [staffOwnerApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: factoryLightTheme(profile: FactoryAppProfile.business),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppointmentActions(
              item: _item(startsIn: const Duration(days: 1)),
              onChanged: () => changed++,
              child: const Text('row'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('row'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to another time'));
    await tester.pumpAndSettle();
    expect(find.byType(FactoryTimeSlot), findsNWidgets(2));

    await tester.tap(find.byType(FactoryTimeSlot).first);
    await tester.pumpAndSettle();

    expect(api.calls, ['move b1 s2']);
    expect(changed, 1);
    expect(find.text('Moved. The customer has been told.'), findsOneWidget);
    expect(find.byType(FactoryTimeSlot), findsNothing);
  });

  testWidgets('moving with nothing free says so', (tester) async {
    await _pump(tester, _FakeApi(), _item(startsIn: const Duration(days: 1)));
    await tester.tap(find.text('Move to another time'));
    await tester.pumpAndSettle();
    expect(find.text('No other free times right now.'), findsOneWidget);
  });

  testWidgets('a time that was just taken shows an error and keeps the sheet open', (tester) async {
    final api = _FakeApi(options: [_option('s2', DateTime.now().add(const Duration(days: 2)))], failMove: true);
    await _pump(tester, api, _item(startsIn: const Duration(days: 1)));
    await tester.tap(find.text('Move to another time'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FactoryTimeSlot));
    await tester.pumpAndSettle();
    expect(find.text('Could not do that. Try again.'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('after the start: the visit happened', (tester) async {
    final api = _FakeApi();
    await _pump(tester, api, _item(startsIn: const Duration(hours: -2)));
    expect(find.text('Move to another time'), findsNothing);
    await tester.tap(find.text('Visit done'));
    await tester.pumpAndSettle();
    expect(api.calls, ['complete b1']);
  });

  testWidgets('after the start: the customer did not come', (tester) async {
    final api = _FakeApi();
    await _pump(tester, api, _item(startsIn: const Duration(hours: -2)));
    await tester.tap(find.text('Customer did not come'));
    await tester.pumpAndSettle();
    expect(api.calls, ['noshow b1']);
  });

  testWidgets('a started but unpaid appointment offers nothing to finish', (tester) async {
    await _pump(tester, _FakeApi(), _item(startsIn: const Duration(hours: -2), status: 'PENDING_PAYMENT'));
    expect(find.text('Visit done'), findsNothing);
    expect(find.text('Customer did not come'), findsNothing);
    expect(find.text('Move to another time'), findsNothing);
  });

  testWidgets('the move sheet fits a 320 px phone with a large font in the dark theme', (tester) async {
    final day = DateTime.now().add(const Duration(days: 2));
    final api = _FakeApi(options: [for (var i = 0; i < 12; i++) _option('s$i', day.add(Duration(hours: i)))]);
    await _pump(
      tester,
      api,
      _item(startsIn: const Duration(days: 1)),
      size: const Size(320, 640),
      textScale: 2,
      dark: true,
    );
    await tester.tap(find.text('Move to another time'));
    await tester.pumpAndSettle();
    expect(find.byType(FactoryTimeSlot), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
