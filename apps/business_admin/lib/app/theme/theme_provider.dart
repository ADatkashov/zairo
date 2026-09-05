import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Provider to manage the application's [ThemeMode]. Mirrors
/// apps/user_app's identical provider. Defaults to [ThemeMode.system] and,
/// same as user_app, isn't persisted across restarts — only the language
/// choice is.
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});
