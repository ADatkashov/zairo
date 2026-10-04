import '../../l10n/app_localizations.dart';

/// Shared "MMM d, HH:mm" formatter (e.g. "Jan 1, 10:00") for booking/slot
/// timestamps — used by both MyBookingsScreen's booking cards and
/// ProviderDetailScreen's time slots, so the two stay visually consistent
/// and share one localized month-name list instead of two copies.
String _monthName(AppLocalizations l10n, int month) => [
      l10n.monthJan,
      l10n.monthFeb,
      l10n.monthMar,
      l10n.monthApr,
      l10n.monthMay,
      l10n.monthJun,
      l10n.monthJul,
      l10n.monthAug,
      l10n.monthSep,
      l10n.monthOct,
      l10n.monthNov,
      l10n.monthDec,
    ][month - 1];

String formatMonthDayTime(AppLocalizations l10n, DateTime dt) {
  return '${_monthName(l10n, dt.month)} ${dt.day}, ${formatHourMinute(dt)}';
}

String formatHourMinute(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// "Mon" / "Пн" — [dt].weekday is 1 (Monday) to 7 (Sunday).
String formatWeekdayShort(AppLocalizations l10n, DateTime dt) => [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ][dt.weekday - 1];

String formatMonthShort(AppLocalizations l10n, DateTime dt) => _monthName(l10n, dt.month);

/// "Mon, Oct 5"
String formatWeekdayMonthDay(AppLocalizations l10n, DateTime dt) =>
    '${formatWeekdayShort(l10n, dt)}, ${_monthName(l10n, dt.month)} ${dt.day}';
