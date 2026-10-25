import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/features/dashboard/data/dashboard_trends.dart';

void main() {
  test('parses the daily series oldest first and totals it', () {
    final trends = DashboardTrends.fromJson({
      'bookingsCreated': [
        {'date': '2026-10-12', 'count': 2},
        {'date': '2026-10-13', 'count': 0},
        {'date': '2026-10-14', 'count': 5},
      ],
    });
    expect(trends.bookingsCreated, [2, 0, 5]);
    expect(trends.bookingsTotal, 7);
  });

  test('a missing series is empty, not an error', () {
    expect(DashboardTrends.fromJson({}).bookingsCreated, isEmpty);
    expect(const DashboardTrends.empty().bookingsTotal, 0);
  });

  group('bookingsWeekChange', () {
    DashboardTrends series(List<num> counts) => DashboardTrends.fromJson({
      'bookingsCreated': [
        for (var i = 0; i < counts.length; i++) {'date': '2026-10-${i + 1}', 'count': counts[i]},
      ],
    });

    test('compares the last 7 days with the 7 before them', () {
      // 1..7 = 28, then 8..14 = 77.
      expect(series([for (var i = 1; i <= 14; i++) i]).bookingsWeekChange, 175);
      expect(series([...List.filled(7, 10), ...List.filled(7, 5)]).bookingsWeekChange, -50);
      expect(series(List.filled(14, 3)).bookingsWeekChange, 0);
    });

    test('only the last two weeks count when the series is longer', () {
      expect(series([999, 999, ...List.filled(7, 10), ...List.filled(7, 20)]).bookingsWeekChange, 100);
    });

    test('is absent without two full weeks, or without a baseline', () {
      expect(series([for (var i = 1; i <= 13; i++) i]).bookingsWeekChange, isNull);
      expect(const DashboardTrends.empty().bookingsWeekChange, isNull);
      expect(series([...List.filled(7, 0), ...List.filled(7, 4)]).bookingsWeekChange, isNull, reason: 'a rise from zero has no percentage');
    });
  });
}
