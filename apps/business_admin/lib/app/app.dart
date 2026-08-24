import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_config.dart';
import '../l10n/app_localizations.dart';
import 'auth_gate.dart';
import 'locale/locale_controller.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

class BusinessAdminApp extends ConsumerWidget {
  const BusinessAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeControllerProvider).value;

    return MaterialApp(
      title: AppConfig.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthGate(),
    );
  }
}
