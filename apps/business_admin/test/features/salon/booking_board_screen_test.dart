import 'package:business_admin/features/salon/data/models/schedule_entry.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/features/salon/presentation/screens/booking_board_screen.dart';
import 'package:business_admin/features/salon/presentation/screens/week_calendar_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Wed 7 Oct 2026: that week runs Mon 5 – Sun 11.
final _today = DateTime(2026, 10, 7);

AgendaItem _item(String id, String status, {String provider = 'Glow Salon', String service = 'Gel manicure', int day = 7}) {
  final at = DateTime(2026, 10, day, 12);
  return AgendaItem(
    entry: ScheduleEntry(
      bookingId: id,
      serviceId: 's1',
      availabilitySlotId: 'slot-$id',
      status: status,
      startsAt: at.toUtc(),
      endsAt: at.add(const Duration(minutes: 60)).toUtc(),
      totalPrice: 8500,
      currency: 'KZT',
    ),
    providerId: provider,
    providerName: provider,
    serviceTitle: service,
  );
}

Future<List<(String, DateTime)>> _pump(
  WidgetTester tester,
  List<AgendaItem>? items, {
  Size size = const Size(1000, 900),
  Widget? home,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final requested = <(String, DateTime)>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ownerWeekAgendaProvider.overrideWith((ref, key) {
          requested.add(key);
          return items == null ? Future.error(StateError('offline')) : Future.value(items);
        }),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home ?? BookingBoardScreen(ownerUserId: 'owner-1', today: _today),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return requested;
}

void main() {
  testWidgets('sorts the week into awaiting payment, confirmed, completed and no-show columns', (tester) async {
    await _pump(tester, [
      _item('b1', 'PENDING_PAYMENT', service: 'Haircut'),
      _item('b2', 'PENDING', service: 'Pedicure'),
      _item('b3', 'CONFIRMED', service: 'Massage'),
      _item('b4', 'COMPLETED', service: 'Facial'),
    ]);

    expect(find.text('Booking board'), findsOneWidget);
    for (final title in ['Awaiting payment', 'Confirmed', 'Completed', 'No-show']) {
      expect(find.text(title), findsOneWidget);
    }
    for (final service in ['Haircut', 'Pedicure', 'Massage', 'Facial']) {
      expect(find.text(service), findsOneWidget);
    }
    // Pending + pending-payment share a column, so it counts two; the empty no-show column says so.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('No bookings'), findsOneWidget);
  });

  testWidgets('each card shows when it is, and which business only if there are several', (tester) async {
    await _pump(tester, [_item('b1', 'CONFIRMED')]);
    expect(find.textContaining('12:00'), findsOneWidget);
    expect(find.text('Glow Salon'), findsNothing);

    await _pump(tester, [_item('b1', 'CONFIRMED'), _item('b2', 'COMPLETED', provider: 'Zen Spa')]);
    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Zen Spa'), findsOneWidget);
  });

  testWidgets('stepping a week loads that week', (tester) async {
    final requested = await _pump(tester, [_item('b1', 'CONFIRMED')]);
    expect(requested.last.$2, DateTime(2026, 10, 5));

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(requested.last.$2, DateTime(2026, 10, 12));

    await tester.tap(find.byTooltip('Previous week'));
    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();
    expect(requested.last.$2, DateTime(2026, 9, 28));
  });

  testWidgets('a failed load shows a retry', (tester) async {
    await _pump(tester, null);

    expect(find.byType(FactoryErrorState), findsOneWidget);
  });

  testWidgets('on a phone the columns scroll sideways without overflowing', (tester) async {
    await _pump(tester, [_item('b1', 'CONFIRMED'), _item('b2', 'NO_SHOW')], size: const Size(360, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('Awaiting payment'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(find.text('No-show'), findsOneWidget);
  });

  testWidgets('the calendar opens the board on the week it is showing', (tester) async {
    final requested = await _pump(
      tester,
      [_item('b1', 'CONFIRMED')],
      home: WeekCalendarScreen(ownerUserId: 'owner-1', today: _today),
    );

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Booking board'));
    await tester.pumpAndSettle();

    expect(find.byType(BookingBoardScreen), findsOneWidget);
    expect(requested.last.$2, DateTime(2026, 10, 12));
  });
}
