import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to manage the application's [ThemeMode].
/// Defaults to [ThemeMode.system].
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});
