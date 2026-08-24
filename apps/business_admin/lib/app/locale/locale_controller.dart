import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _localeStorageKey = 'locale_code';

/// The user's language override, persisted across restarts. `null` means
/// "follow the device locale" — MaterialApp's own resolution then picks the
/// closest match from AppLocalizations.supportedLocales, falling back to
/// English (the first entry) if the device locale isn't one Factory ships
/// translations for. Mirrors apps/user_app's identical controller — stored
/// via SecureStorageService only because it's the storage abstraction
/// already wired into this app (auth tokens use it), not because the
/// language choice itself is sensitive.
final localeControllerProvider = AsyncNotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final stored = await ref.read(secureStorageServiceProvider).read(_localeStorageKey);
    return stored == null ? null : Locale(stored);
  }

  Future<void> setLocale(Locale? locale) async {
    state = AsyncData(locale);
    final storage = ref.read(secureStorageServiceProvider);
    if (locale == null) {
      await storage.delete(_localeStorageKey);
    } else {
      await storage.write(_localeStorageKey, locale.languageCode);
    }
  }
}
