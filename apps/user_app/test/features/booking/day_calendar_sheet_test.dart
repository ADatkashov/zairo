import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/presentation/widgets/day_calendar_sheet.dart';
import 'package:zairo/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  final jan = DateTime(2026, 1, 5);
  final mar = DateTime(2026, 3, 9);

  testWidgets('walks between the months that have free days, and no further', (tester) async {
    await tester.pumpWidget(_app(DayCalendar(availableDays: {jan, mar}, selectedDay: jan, today: DateTime(2026, 1, 2))));

    expect(find.text('Jan 2026'), findsOneWidget);
    Finder byTooltip(String t) => find.ancestor(of: find.byTooltip(t), matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(byTooltip('Previous month')).onPressed, isNull, reason: 'nothing before January');
    expect(tester.widget<IconButton>(byTooltip('Next month')).onPressed, isNotNull);

    await tester.tap(byTooltip('Next month'));
    await tester.pump();
    expect(find.text('Feb 2026'), findsOneWidget);
    await tester.tap(byTooltip('Next month'));
    await tester.pump();
    expect(find.text('Mar 2026'), findsOneWidget);
    expect(tester.widget<IconButton>(byTooltip('Next month')).onPressed, isNull, reason: 'nothing after March');
    expect(tester.widget<IconButton>(byTooltip('Previous month')).onPressed, isNotNull);
  });

  testWidgets('free days are tappable and read aloud as free; others as having no free times', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(DayCalendar(availableDays: {jan}, selectedDay: jan, today: DateTime(2026, 1, 2))));

    expect(find.bySemanticsLabel('Mon, Jan 5: free times'), findsOneWidget);
    expect(find.bySemanticsLabel('Tue, Jan 6: no free times'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the weeks start on Monday: January 2026 begins on a Thursday', (tester) async {
    await tester.pumpWidget(_app(DayCalendar(availableDays: {jan}, selectedDay: jan, today: DateTime(2026, 1, 2))));

    final mon = tester.getTopLeft(find.text('Mon').first).dx;
    final thu = tester.getTopLeft(find.text('Thu').first).dx;
    // Day 1 sits under Thursday (the 4th column), not under Monday.
    final first = tester.getTopLeft(find.text('1').first).dx;
    expect((first - thu).abs(), lessThan((first - mon).abs()));
  });

  testWidgets('pops the tapped free day', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async => picked = await showDayCalendarSheet(context, availableDays: {jan}, selectedDay: jan),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(picked, jan);
  });
}
