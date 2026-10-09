import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/city/presentation/providers/city_providers.dart';
import 'package:zairo/features/city/presentation/screens/city_selection_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

void main() {
  testWidgets('a failed city load shows a plain message with a retry, never the raw exception', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCitiesProvider.overrideWith((ref) async {
            attempts++;
            throw Exception('DioException [connection error] https://api.internal/secret');
          }),
          userCurrentCityProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CitySelectionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load cities. Please try again."), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('secret'), findsNothing);

    final before = attempts;
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();
    expect(attempts, greaterThan(before));
  });
}
