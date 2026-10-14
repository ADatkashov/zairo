import 'package:business_admin/features/salon/presentation/widgets/analytics_period.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wednesday 2026-10-14 15:30.
  final now = DateTime(2026, 10, 14, 15, 30);

  test('today is this calendar day', () {
    expect(analyticsRangeFor(AnalyticsPeriod.today, null, now: now), (DateTime(2026, 10, 14), DateTime(2026, 10, 15)));
  });

  test('this week runs Monday to the next Monday', () {
    expect(analyticsRangeFor(AnalyticsPeriod.thisWeek, null, now: now), (DateTime(2026, 10, 12), DateTime(2026, 10, 19)));
  });

  test('this month runs to the first of the next month', () {
    expect(analyticsRangeFor(AnalyticsPeriod.thisMonth, null, now: now), (DateTime(2026, 10, 1), DateTime(2026, 11, 1)));
  });

  test('December rolls over into January of the next year', () {
    expect(
      analyticsRangeFor(AnalyticsPeriod.thisMonth, null, now: DateTime(2026, 12, 20)),
      (DateTime(2026, 12, 1), DateTime(2027, 1, 1)),
    );
  });

  test('a picked custom range includes its last day', () {
    final picked = DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30));
    expect(analyticsRangeFor(AnalyticsPeriod.custom, picked, now: now), (DateTime(2026, 9, 1), DateTime(2026, 10, 1)));
  });

  test('custom before anything is picked is the month so far', () {
    expect(analyticsRangeFor(AnalyticsPeriod.custom, null, now: now), (DateTime(2026, 10, 1), now));
  });
}
