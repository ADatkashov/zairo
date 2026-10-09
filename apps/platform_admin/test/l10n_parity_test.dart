import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _keys(String locale) {
  final json = jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;
  return json.keys.where((k) => !k.startsWith('@')).toSet();
}

void main() {
  // A string missing from ru/kk silently shows in English to those users.
  for (final locale in ['ru', 'kk']) {
    test('every English string also exists in $locale', () {
      expect(_keys('en').difference(_keys(locale)), isEmpty);
    });
    test('$locale has no strings English lacks', () {
      expect(_keys(locale).difference(_keys('en')), isEmpty);
    });
  }
}
