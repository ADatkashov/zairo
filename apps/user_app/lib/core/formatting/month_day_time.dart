import '../../l10n/app_localizations.dart';

/// Shared "MMM d, HH:mm" formatter (e.g. "Jan 1, 10:00") for booking/slot
/// timestamps — used by both MyBookingsScreen's booking cards and
/// ProviderDetailScreen's time slots, so the two stay visually consistent
/// and share one localized month-name list instead of two copies.
String formatMonthDayTime(AppLocalizations l10n, DateTime dt) {
  final months = [
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
  ];
  final month = months[dt.month - 1];
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$month ${dt.day}, $hour:$minute';
}
