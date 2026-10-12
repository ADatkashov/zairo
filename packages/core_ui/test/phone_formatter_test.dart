import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

String _type(String text) => const KzPhoneInputFormatter()
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
    .text;

void main() {
  group('formatKzPhone', () {
    test('keeps the fixed +7 prefix on empty input', () {
      expect(formatKzPhone(''), '+7 ');
      expect(formatKzPhone('+7'), '+7 ');
      expect(formatKzPhone('+7 '), '+7 ');
    });

    test('groups digits as +7 XXX XXX XX XX while typing', () {
      expect(formatKzPhone('+7 7'), '+7 7');
      expect(formatKzPhone('+7 700'), '+7 700');
      expect(formatKzPhone('+7 7001'), '+7 700 1');
      expect(formatKzPhone('+7 700123'), '+7 700 123');
      expect(formatKzPhone('+7 7001234'), '+7 700 123 4');
      expect(formatKzPhone('+7 700123456'), '+7 700 123 45 6');
      expect(formatKzPhone('+7 7001234567'), '+7 700 123 45 67');
    });

    test('normalises pasted 8… / 7… / +7… / bare 10-digit numbers', () {
      for (final raw in ['87001234567', '77001234567', '+77001234567', '7001234567', '8 (700) 123-45-67']) {
        expect(formatKzPhone(raw), '+7 700 123 45 67', reason: raw);
      }
    });

    test('never exceeds ten national digits', () {
      expect(formatKzPhone('+7 700 123 45 67 89'), '+7 700 123 45 67');
    });

    test('drops letters and punctuation', () {
      expect(formatKzPhone('+7 7a0b0-1'), '+7 700 1');
    });
  });

  test('isCompleteKzPhone requires all ten digits', () {
    expect(isCompleteKzPhone('+7 700 123 45 67'), isTrue);
    expect(isCompleteKzPhone('+7 700 123 45 6'), isFalse);
    expect(isCompleteKzPhone('+7'), isFalse);
    expect(isCompleteKzPhone(null), isFalse);
  });

  test('formatter formats and parks the cursor at the end', () {
    final v = const KzPhoneInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '+7 70012'));
    expect(v.text, '+7 700 12');
    expect(v.selection.baseOffset, v.text.length);
    expect(_type('+7'), '+7 ');
  });
}
