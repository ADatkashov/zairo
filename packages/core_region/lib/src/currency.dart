/// ISO 4217 code -> display symbol, for the currencies named in the Factory
/// Country Architecture document's initial market list. An unmapped code
/// falls back to the code itself (e.g. "100 XYZ") rather than guessing or
/// silently defaulting to tenge — the exact hardcoding this map exists to
/// replace (see `RegionDefaults` and `core_ui`'s `FactoryPriceText`).
const Map<String, String> _currencySymbols = {
  'KZT': '₸',
  'UZS': "so'm",
  'KGS': 'с',
  'TRY': '₺',
  'RUB': '₽',
  'USD': r'$',
  'EUR': '€',
  'CNY': '¥',
};

String currencySymbolFor(String currencyCode) => _currencySymbols[currencyCode] ?? currencyCode;
