import '../../l10n/app_localizations.dart';
import 'month_day_time.dart';

/// "Today 18:30" / "Tomorrow 10:00" / falls back to [formatMonthDayTime]
/// beyond that — the provider card's availability badge, from the search
/// result's `nextAvailableSlot` (see ProviderSearchResult). [dt] must
/// already be local (call `.toLocal()` at the call site) — same contract
/// [formatMonthDayTime] itself expects.
String formatNextAvailable(AppLocalizations l10n, DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  if (target == today) {
    return l10n.nextAvailableTodayLabel(time);
  }
  if (target == today.add(const Duration(days: 1))) {
    return l10n.nextAvailableTomorrowLabel(time);
  }
  return formatMonthDayTime(l10n, dt);
}
