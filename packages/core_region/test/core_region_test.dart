import 'package:core_region/core_region.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('currencySymbolFor', () {
    test('maps known ISO 4217 codes to their display symbol', () {
      expect(currencySymbolFor('KZT'), '₸');
      expect(currencySymbolFor('USD'), r'$');
      expect(currencySymbolFor('EUR'), '€');
      expect(currencySymbolFor('RUB'), '₽');
      expect(currencySymbolFor('TRY'), '₺');
      expect(currencySymbolFor('CNY'), '¥');
    });

    test('falls back to the code itself for an unmapped currency, never to tenge', () {
      expect(currencySymbolFor('XYZ'), 'XYZ');
    });
  });

  group('Country.fromJson', () {
    test('parses the backend CountryResponse shape', () {
      final country = Country.fromJson({
        'code': 'KZ',
        'name': 'Kazakhstan',
        'defaultLanguage': 'kk',
        'supportedLanguages': ['kk', 'ru', 'en'],
        'currency': 'KZT',
        'timezone': 'Asia/Almaty',
        'numberFormat': '1 000,50',
        'dateFormat': 'dd.MM.yyyy',
        'status': 'ACTIVE',
      });

      expect(country.code, 'KZ');
      expect(country.supportedLanguages, ['kk', 'ru', 'en']);
      expect(country.currency, 'KZT');
    });
  });

  group('RegionDefaults', () {
    test('resolves to the seeded Kazakhstan row, the platform\'s only market today', () {
      expect(RegionDefaults.country.code, 'KZ');
      expect(RegionDefaults.currencySymbol, '₸');
    });
  });
}
