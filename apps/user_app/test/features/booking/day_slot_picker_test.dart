import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/data/models/availability_slot.dart';
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
}
