import 'package:business_admin/l10n/app_localizations.dart';
import 'package:business_admin/l10n/app_localizations_en.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_http.dart';

/// English strings, so tests can say "the localized X" instead of repeating copy.
final AppLocalizations en = AppLocalizationsEn();

/// [home] on the real providers and the real API classes, with only the network
/// replaced by [http]. [overrides] swap individual providers when a test needs to.
Widget appOn(FakeHttp http, Widget home, {List<Override> overrides = const [], Locale locale = const Locale('en')}) {
  return ProviderScope(
    overrides: [dioClientProvider.overrideWithValue(http.client()), ...overrides],
    child: MaterialApp(
      theme: factoryLightTheme(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// Makes the test window tall and wide enough that a long ListView is fully built.
void useTallScreen(WidgetTester tester, {Size size = const Size(800, 3000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
