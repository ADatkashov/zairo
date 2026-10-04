import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups by local day, sorted by day and time', () {
    final a = DateTime(2026, 10, 6, 15);
    final b = DateTime(2026, 10, 5, 10);
    final c = DateTime(2026, 10, 5, 9);
    final grouped = groupByLocalDay<DateTime>([a, b, c], (d) => d);
    expect(grouped.keys.toList(), [DateTime(2026, 10, 5), DateTime(2026, 10, 6)]);
    expect(grouped[DateTime(2026, 10, 5)], [c, b]);
    expect(grouped[DateTime(2026, 10, 6)], [a]);
  });

  test('empty input gives an empty map', () {
    expect(groupByLocalDay<DateTime>(const [], (d) => d), isEmpty);
  });
}
