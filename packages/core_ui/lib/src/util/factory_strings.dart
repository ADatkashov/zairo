import 'package:flutter/widgets.dart';

/// The handful of built-in labels core_ui widgets show when a caller does not
/// pass its own (retry buttons, the password eye, search clear/filter…).
/// core_ui has no ARB pipeline, so these ship in the three product
/// languages directly; any other locale falls back to English. Apps that
/// need different wording still override per widget.
class FactoryStrings {
  const FactoryStrings._(this._table);

  final Map<String, String> _table;

  /// Resolves from the ambient [Localizations] locale, defaulting to English
  /// when no localizations are mounted (e.g. a bare widget test).
  static FactoryStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return FactoryStrings.forLanguage(locale?.languageCode);
  }

  static FactoryStrings forLanguage(String? languageCode) =>
      FactoryStrings._(_tables[languageCode] ?? _tables['en']!);

  String get retry => _table['retry']!;
  String get showPassword => _table['showPassword']!;
  String get hidePassword => _table['hidePassword']!;
  String get filters => _table['filters']!;
  String get clear => _table['clear']!;
  String get addToFavorites => _table['addToFavorites']!;
  String get removeFromFavorites => _table['removeFromFavorites']!;

  static const _tables = <String, Map<String, String>>{
    'en': {
      'retry': 'Try again',
      'showPassword': 'Show password',
      'hidePassword': 'Hide password',
      'filters': 'Filters',
      'clear': 'Clear',
      'addToFavorites': 'Add to favorites',
      'removeFromFavorites': 'Remove from favorites',
    },
    'ru': {
      'retry': 'Повторить',
      'showPassword': 'Показать пароль',
      'hidePassword': 'Скрыть пароль',
      'filters': 'Фильтры',
      'clear': 'Очистить',
      'addToFavorites': 'Добавить в избранное',
      'removeFromFavorites': 'Убрать из избранного',
    },
    'kk': {
      'retry': 'Қайталау',
      'showPassword': 'Құпиясөзді көрсету',
      'hidePassword': 'Құпиясөзді жасыру',
      'filters': 'Сүзгілер',
      'clear': 'Тазалау',
      'addToFavorites': 'Таңдаулыларға қосу',
      'removeFromFavorites': 'Таңдаулылардан алып тастау',
    },
  };
}
