import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'preferences.dart';
import 'router.dart';

class PlatformAdminApp extends ConsumerWidget {
  const PlatformAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: factoryLightTheme(),
      darkTheme: factoryDarkTheme(),
      themeMode: ref.watch(themeModeControllerProvider).value,
      locale: ref.watch(localeControllerProvider).value,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
