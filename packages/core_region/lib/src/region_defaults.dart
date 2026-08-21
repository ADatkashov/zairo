import 'country.dart';
import 'currency.dart';

/// The platform's only market today, matching the seeded row in the
/// backend's `country` table (V15__create_country_table.sql) exactly.
///
/// This is a placeholder, not the architecture: nothing here assumes
/// Kazakhstan stays the only entry. Once the apps fetch `GET
/// /api/v1/countries/{code}` for the signed-in user (Phase C), call sites
/// move from `RegionDefaults.country` to that resolved value — this class
/// just gives every current call site (e.g. `FactoryPriceText`'s default
/// currency symbol) one named, documented place to point at in the
/// meantime, instead of a bare literal buried in a presentation widget.
class RegionDefaults {
  RegionDefaults._();

  static const country = Country(
    code: 'KZ',
    name: 'Kazakhstan',
    defaultLanguage: 'kk',
    supportedLanguages: ['kk', 'ru', 'en'],
    currency: 'KZT',
    timezone: 'Asia/Almaty',
    numberFormat: '1 000,50',
    dateFormat: 'dd.MM.yyyy',
    status: 'ACTIVE',
  );

  static String get currencySymbol => currencySymbolFor(country.currency);
}
