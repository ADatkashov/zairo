import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/core/formatting/opening_hours.dart';

void main() {
  // 2024-01-01 is a Monday.
  DateTime at(int dayOffset, int h, int m) =>
      DateTime(2024, 1, 1 + dayOffset, h, m);
  const week = {
    'mon': '09:00-20:00',
    'tue': '09:00-20:00',
    'sat': '10:00-16:00',
  };

  test('no hours -> unknown', () {
    expect(openingStatus(const {}, at(0, 12, 0)).state, OpeningState.unknown);
    expect(
      openingStatus(const {'mon': 'garbage'}, at(0, 12, 0)).state,
      OpeningState.unknown,
    );
  });

  test('inside the range -> open until the closing time', () {
    final s = openingStatus(week, at(0, 12, 0));
    expect(s.state, OpeningState.open);
    expect(s.time, '20:00');
  });

  test('the opening minute is open, the closing minute is closed', () {
    expect(openingStatus(week, at(0, 9, 0)).state, OpeningState.open);
    expect(openingStatus(week, at(0, 20, 0)).state, OpeningState.closed);
  });

  test('before opening -> opens later today', () {
    final s = openingStatus(week, at(0, 7, 30));
    expect(s.state, OpeningState.closed);
    expect(s.daysAhead, 0);
    expect(s.time, '09:00');
    expect(s.dayKey, 'mon');
  });

  test('after closing -> opens tomorrow', () {
    final s = openingStatus(week, at(0, 21, 0));
    expect(s.state, OpeningState.closed);
    expect(s.daysAhead, 1);
    expect(s.dayKey, 'tue');
    expect(s.time, '09:00');
  });

  test('closed day -> next open day further ahead, wrapping the week', () {
    final wed = openingStatus(week, at(2, 12, 0));
    expect(
      (wed.state, wed.daysAhead, wed.dayKey, wed.time),
      (OpeningState.closed, 3, 'sat', '10:00'),
    );
    final sat = openingStatus(week, at(5, 17, 0));
    expect(
      (sat.state, sat.daysAhead, sat.dayKey),
      (OpeningState.closed, 2, 'mon'),
    );
  });

  test(
    'a single open weekday asked after closing wraps to the same day next week',
    () {
      final s = openingStatus(const {'mon': '09:00-10:00'}, at(0, 11, 0));
      expect((s.daysAhead, s.dayKey), (7, 'mon'));
    },
  );

  test('hoursOf', () {
    expect(hoursOf(week, 'sat')?.start, '10:00');
    expect(hoursOf(week, 'sun'), isNull);
    expect(hoursOf(const {'mon': 'x'}, 'mon'), isNull);
  });
}
