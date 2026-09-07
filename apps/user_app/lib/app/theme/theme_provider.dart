import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_config.dart';

/// The user's theme choice, persisted across restarts — same
/// SecureStorageService-backed pattern as [LocaleController]. Without this,
/// a switch to light/dark only lived in memory: the provider silently reset
/// to [ThemeMode.system] on every cold start, which reads as "my choice
/// didn't stick" whenever the device itself is in dark mode.
final themeModeControllerProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
      ThemeModeController.new,
    );

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final stored = await ref
        .read(secureStorageServiceProvider)
        .read(AppConfig.themeModeKey);
    return ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    await ref
        .read(secureStorageServiceProvider)
        .write(AppConfig.themeModeKey, mode.name);
  }
}
