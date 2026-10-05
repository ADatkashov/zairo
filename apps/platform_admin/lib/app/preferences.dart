import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _localeKey = 'locale_code';
const _themeKey = 'theme_mode';

/// The language override, persisted across restarts. `null` follows the
/// device (MaterialApp then picks the closest supported locale, English if
/// none matches).
final localeControllerProvider = AsyncNotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final stored = await ref.read(secureStorageServiceProvider).read(_localeKey);
    return stored == null ? null : Locale(stored);
  }

  Future<void> setLocale(Locale? locale) async {
    state = AsyncData(locale);
    final storage = ref.read(secureStorageServiceProvider);
    if (locale == null) {
      await storage.delete(_localeKey);
    } else {
      await storage.write(_localeKey, locale.languageCode);
    }
  }
}

/// Light / dark / follow-the-device, persisted across restarts.
final themeModeControllerProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final stored = await ref.read(secureStorageServiceProvider).read(_themeKey);
    return ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    await ref.read(secureStorageServiceProvider).write(_themeKey, mode.name);
  }
}
