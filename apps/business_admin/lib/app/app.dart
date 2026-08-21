import 'package:flutter/material.dart';

import '../core/constants/app_config.dart';
import '../l10n/app_localizations.dart';
import 'auth_gate.dart';
import 'theme/app_theme.dart';

class BusinessAdminApp extends StatelessWidget {
  const BusinessAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthGate(),
    );
  }
}
