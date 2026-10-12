import 'package:flutter/services.dart';

/// Kazakhstan (+7) phone numbers: `+7 XXX XXX XX XX` — ten national digits,
/// no more, no fewer.
const int kzNationalDigits = 10;

/// The national digits (without the `+7` / `8` country prefix) typed or
/// pasted into [text], capped at [kzNationalDigits]. Accepts `+7 700…`,
/// `8 700…`, `7700…` (11 digits) and a bare 10-digit `700…`.
String kzNationalDigitsOf(String text) {
  final t = text.trim();
  var digits = t.replaceAll(RegExp(r'\D'), '');
  if (t.startsWith('+7')) {
    digits = digits.substring(1);
  } else if (digits.length > kzNationalDigits && (digits.startsWith('7') || digits.startsWith('8'))) {
    digits = digits.substring(1);
  }
  return digits.length > kzNationalDigits ? digits.substring(0, kzNationalDigits) : digits;
}

/// Formats [text] as `+7 XXX XXX XX XX`, growing as digits are entered
/// (`+7 `, `+7 700`, `+7 700 123`, `+7 700 123 45`, `+7 700 123 45 67`).
String formatKzPhone(String text) {
  final d = kzNationalDigitsOf(text);
  final buf = StringBuffer('+7');
  const groups = [3, 3, 2, 2];
  var pos = 0;
  for (final size in groups) {
    if (pos >= d.length) break;
    final end = pos + size > d.length ? d.length : pos + size;
    buf
      ..write(' ')
      ..write(d.substring(pos, end));
    pos = end;
  }
  if (d.isEmpty) buf.write(' ');
  return buf.toString();
}

/// True when [text] holds a full Kazakhstan number (`+7` and ten digits).
bool isCompleteKzPhone(String? text) => text != null && kzNationalDigitsOf(text).length == kzNationalDigits;

/// Live `+7 XXX XXX XX XX` mask for a phone [TextField]. The `+7 ` prefix is
/// fixed (it can't be deleted), non-digits are dropped and the number can't
/// exceed ten digits.
class KzPhoneInputFormatter extends TextInputFormatter {
  const KzPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = formatKzPhone(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
