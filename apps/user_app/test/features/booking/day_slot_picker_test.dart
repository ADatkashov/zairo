import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/data/models/availability_slot.dart';
import 'package:zairo/features/booking/presentation/widgets/day_calendar_sheet.dart';
import 'package:zairo/features/booking/presentation/widgets/day_slot_picker.dart';
import 'package:zairo/l10n/app_localizations.dart';

AvailabilitySlot _slot(String id, DateTime start) => AvailabilitySlot(
      id: id,
      providerId: 'p1',
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 30)),
      status: 'OPEN',
    );

void main() {
  testWidgets('shows the first day\'s times and switches when another day is tapped', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DaySlotPicker(
            slots: [
              _slot('a', DateTime(2026, 1, 1, 10)),
              _slot('b', DateTime(2026, 1, 1, 11)),
              _slot('c', DateTime(2026, 1, 2, 14)),
            ],
            selectedSlotId: null,
            onSelected: (id) => selected = id,
          ),
        ),
      ),
    );

    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('11:00'), findsOneWidget);
    expect(find.text('14:00'), findsNothing);

    await tester.tap(find.text('Fri'));
    await tester.pump();
    expect(find.text('14:00'), findsOneWidget);
    expect(find.text('10:00'), findsNothing);

    await tester.tap(find.text('14:00'));
    expect(selected, 'c');
  });

  Widget app(Widget child) => MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('Soonest', () {
    testWidgets('offers the three earliest times across days as one-tap chips', (tester) async {
      String? selected;
      await tester.pumpWidget(app(DaySlotPicker(
        slots: [
          _slot('a', DateTime(2099, 1, 1, 10)),
          _slot('b', DateTime(2099, 1, 1, 11)),
          _slot('c', DateTime(2099, 1, 2, 14)),
          _slot('d', DateTime(2099, 1, 3, 9)),
        ],
        selectedSlotId: null,
        onSelected: (id) => selected = id,
      )));

      expect(find.text('Soonest'), findsOneWidget);
      final chips = find.descendant(of: find.byKey(const Key('bookingSoonest')), matching: find.byType(FactoryTimeSlot));
      expect(chips, findsNWidgets(3));
      // A far day is labelled with its date, not "Today".
      expect(find.text('Thu, Jan 1 · 10:00'), findsOneWidget);

      await tester.tap(find.text('Fri, Jan 2 · 14:00'));
      expect(selected, 'c');
    });

    testWidgets('picking one highlights it and shows its day below', (tester) async {
      await tester.pumpWidget(app(DaySlotPicker(
        slots: [
          _slot('a', DateTime(2099, 1, 1, 10)),
          _slot('c', DateTime(2099, 1, 2, 14)),
        ],
        selectedSlotId: 'c',
        onSelected: (_) {},
      )));

      final selectedChip = tester.widget<FactoryTimeSlot>(find.widgetWithText(FactoryTimeSlot, 'Fri, Jan 2 · 14:00'));
      expect(selectedChip.state, FactoryTimeSlotState.selected);
      expect(find.text('14:00'), findsOneWidget, reason: 'the chosen slot\'s day is open under the strip');
    });

    testWidgets('one day with a handful of times needs no shortcut', (tester) async {
      await tester.pumpWidget(app(DaySlotPicker(
        slots: [_slot('a', DateTime(2099, 1, 1, 10)), _slot('b', DateTime(2099, 1, 1, 11))],
        selectedSlotId: null,
        onSelected: (_) {},
      )));

      expect(find.text('Soonest'), findsNothing);
    });

    testWidgets('says Today and Tomorrow for the next two days', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.pumpWidget(app(DaySlotPicker(
        slots: [
          _slot('a', today.add(const Duration(hours: 23, minutes: 30))),
          _slot('b', DateTime(today.year, today.month, today.day + 1, 10)),
          _slot('c', DateTime(today.year, today.month, today.day + 5, 10)),
        ],
        selectedSlotId: null,
        onSelected: (_) {},
      )));

      expect(find.text('Today 23:30'), findsOneWidget);
      expect(find.text('Tomorrow 10:00'), findsOneWidget);
    });
  });

  group('times of the day', () {
    List<AvailabilitySlot> hours(Iterable<int> hs) => [for (final h in hs) _slot('s$h', DateTime(2099, 1, 1, h))];

    testWidgets('a busy day is grouped into morning, afternoon and evening', (tester) async {
      await tester.pumpWidget(app(DaySlotPicker(
        slots: hours([9, 10, 11, 12, 14, 16, 17, 19]),
        selectedSlotId: null,
        onSelected: (_) {},
      )));

      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Afternoon'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);
      // 12:00 is afternoon, 17:00 evening.
      final afternoon = tester.getTopLeft(find.text('Afternoon')).dy;
      final evening = tester.getTopLeft(find.text('Evening')).dy;
      expect(tester.getTopLeft(find.text('12:00')).dy, greaterThan(afternoon));
      expect(tester.getTopLeft(find.text('17:00')).dy, greaterThan(evening));
    });

    testWidgets('empty parts of the day get no heading', (tester) async {
      await tester.pumpWidget(app(DaySlotPicker(
        slots: hours([9, 10, 11, 8, 7, 6, 5]),
        selectedSlotId: null,
        onSelected: (_) {},
      )));

      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Afternoon'), findsNothing);
      expect(find.text('Evening'), findsNothing);
    });

    testWidgets('a few times stay one plain list', (tester) async {
      await tester.pumpWidget(app(DaySlotPicker(
        slots: hours([9, 14, 18]),
        selectedSlotId: null,
        onSelected: (_) {},
      )));

      expect(find.text('Morning'), findsNothing);
      expect(find.text('14:00'), findsOneWidget);
    });
  });

  group('calendar', () {
    testWidgets('the calendar button opens the month; tapping a free day shows that day\'s times', (tester) async {
      await tester.pumpWidget(app(DaySlotPicker(
        slots: [_slot('a', DateTime(2099, 1, 5, 10)), _slot('c', DateTime(2099, 1, 20, 14))],
        selectedSlotId: null,
        onSelected: (_) {},
      )));
      expect(find.text('10:00'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bookingCalendarButton')));
      await tester.pumpAndSettle();
      expect(find.text('Pick a date'), findsOneWidget);
      expect(find.text('Jan 2099'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(DayCalendar), matching: find.text('20')));
      await tester.pumpAndSettle();

      expect(find.text('Pick a date'), findsNothing);
      expect(find.text('14:00'), findsOneWidget);
      expect(find.text('10:00'), findsNothing);
    });

    testWidgets('a day without free times does nothing when tapped', (tester) async {
      await tester.pumpWidget(app(DaySlotPicker(
        slots: [_slot('a', DateTime(2099, 1, 5, 10))],
        selectedSlotId: null,
        onSelected: (_) {},
      )));

      await tester.tap(find.byKey(const Key('bookingCalendarButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(DayCalendar), matching: find.text('7')));
      await tester.pumpAndSettle();

      expect(find.text('Pick a date'), findsOneWidget, reason: 'still open: day 7 is not selectable');
    });
  });
}
