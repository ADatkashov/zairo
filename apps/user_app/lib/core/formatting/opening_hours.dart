/// Weekday keys in the order the backend uses (Monday first, like [DateTime.weekday] minus one).
const openingDayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

enum OpeningState { unknown, open, closed }

/// Whether a business is open at a moment, and the next time that changes.
class OpeningStatus {
  const OpeningStatus._(
    this.state, {
    this.time,
    this.daysAhead = 0,
    this.dayKey,
  });

  /// Hours not stated (or no day has any).
  static const unknown = OpeningStatus._(OpeningState.unknown);

  final OpeningState state;

  /// `HH:mm` — when open: the closing time today; when closed: the next opening time.
  final String? time;

  /// When closed: 0 = opens later today, 1 = tomorrow, 2..7 = on [dayKey].
  final int daysAhead;
  final String? dayKey;
}

/// The `HH:mm-HH:mm` range of [dayKey], or null when closed / malformed.
({String start, String end})? hoursOf(
  Map<String, String> hours,
  String dayKey,
) {
  final range = hours[dayKey];
  if (range == null) return null;
  final match = RegExp(r'^(\d\d:\d\d)-(\d\d:\d\d)$').firstMatch(range);
  if (match == null) return null;
  return (start: match.group(1)!, end: match.group(2)!);
}

int _minutes(String hhmm) =>
    int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3));

/// Open now / closed (and when it next opens) for [hours] at [now] (the viewer's local time, which is also taken as
/// the business's: the app does not know the business's zone yet — see docs/BOOKING_UX.md).
OpeningStatus openingStatus(Map<String, String> hours, DateTime now) {
  if (openingDayKeys.every((d) => hoursOf(hours, d) == null)) {
    return OpeningStatus.unknown;
  }
  final nowMinutes = now.hour * 60 + now.minute;
  final todayIndex = now.weekday - 1;
  final today = hoursOf(hours, openingDayKeys[todayIndex]);
  if (today != null) {
    if (nowMinutes >= _minutes(today.start) &&
        nowMinutes < _minutes(today.end)) {
      return OpeningStatus._(OpeningState.open, time: today.end);
    }
    if (nowMinutes < _minutes(today.start)) {
      return OpeningStatus._(
        OpeningState.closed,
        time: today.start,
        dayKey: openingDayKeys[todayIndex],
      );
    }
  }
  for (var ahead = 1; ahead <= 7; ahead++) {
    final key = openingDayKeys[(todayIndex + ahead) % 7];
    final range = hoursOf(hours, key);
    if (range != null) {
      return OpeningStatus._(
        OpeningState.closed,
        time: range.start,
        daysAhead: ahead,
        dayKey: key,
      );
    }
  }
  return OpeningStatus.unknown;
}
