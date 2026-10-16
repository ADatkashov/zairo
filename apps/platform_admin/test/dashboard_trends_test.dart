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
}
