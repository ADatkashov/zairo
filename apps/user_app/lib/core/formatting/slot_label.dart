import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// "Today 14:00", "Tomorrow 10:00", or "Oct 21, 14:00" further out — how a free time is named across the app.
String slotLabel(AppLocalizations l10n, String locale, DateTime now, DateTime start) {
  final time = DateFormat.Hm(locale).format(start);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(start.year, start.month, start.day);
  final days = day.difference(today).inDays;
  if (days == 0) return l10n.workerSlotToday(time);
  if (days == 1) return l10n.workerSlotTomorrow(time);
  return DateFormat.MMMd(locale).add_Hm().format(start);
}
