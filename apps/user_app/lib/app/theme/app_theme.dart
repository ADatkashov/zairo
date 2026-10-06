import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Thin per-app wrapper around Factory's shared theme (see
/// packages/core_ui) — kept so app.dart's `AppTheme.light`/`.dark` call
/// sites don't need to know core_ui exists. No user_app-specific overrides
/// yet; add them here, not in core_ui, if this app ever needs to diverge
/// from Business Admin's look.
class AppTheme {
  static ThemeData get light => factoryLightTheme(profile: FactoryAppProfile.consumer);

  static ThemeData get dark => factoryDarkTheme(profile: FactoryAppProfile.consumer);
}
