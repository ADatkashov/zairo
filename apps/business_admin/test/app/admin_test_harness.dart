import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/app/admin_router.dart';
import 'package:business_admin/app/admin_routes.dart';
import 'package:business_admin/l10n/app_localizations.dart';

/// Pumps the real admin router (auth gate, owner shell, branches) with the
/// given provider [overrides], opened at [location].
Future<void> pumpAdminApp(
  WidgetTester tester, {
  required List<Override> overrides,
  String location = AdminRoutes.dashboard,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: buildAdminRouter(initialLocation: location),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
