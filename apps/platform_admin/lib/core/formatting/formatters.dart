import 'package:intl/intl.dart';

/// Locale-aware date / money text for the console. All backend instants are
/// UTC; people read them in their own time zone.
String formatDateTime(String locale, DateTime value) => DateFormat.yMMMd(locale).add_Hm().format(value.toLocal());

String formatDate(String locale, DateTime value) => DateFormat.yMMMd(locale).format(value.toLocal());

/// "13 500 ₸" — falls back to "13 500 XYZ" for a currency intl doesn't know.
String formatMoney(String locale, num amount, String? currency) {
  final code = (currency == null || currency.isEmpty) ? null : currency;
  final format = code == null
      ? NumberFormat.decimalPattern(locale)
      : NumberFormat.simpleCurrency(locale: locale, name: code, decimalDigits: amount % 1 == 0 ? 0 : 2);
  return format.format(amount);
}

String formatCount(String locale, num value) => NumberFormat.decimalPattern(locale).format(value);
