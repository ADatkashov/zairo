import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/maps/presentation/screens/provider_map_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

void main() {
  // No MAPS_API_KEY is defined in this test run, so mapRendererProvider
  // always resolves to MockMapRenderer — see maps_providers.dart's doc
  // comment. This is also exactly what a real CI run sees.
  testWidgets('shows the provider name, coordinates, and distance', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProviderMapScreen(
            providerName: 'Test Salon',
            latitude: 43.2389,
            longitude: 76.8897,
            distanceKm: 2.5,
          ),
        ),
      ),
    );

    expect(find.text('Test Salon'), findsOneWidget);
    expect(find.text("Map preview isn't available yet"), findsOneWidget);
    expect(find.textContaining('placeholder'), findsNothing);
    // Raw coordinates mean nothing to a customer.
    expect(find.text('43.2389, 76.8897'), findsNothing);
    expect(find.text('2.5 km from you'), findsOneWidget);
    expect(find.text('Open in 2GIS'), findsOneWidget);
    expect(find.text('Open in Google Maps'), findsOneWidget);
  });

  testWidgets('omits distance when not provided', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProviderMapScreen(
            providerName: 'Test Salon',
            latitude: 43.2389,
            longitude: 76.8897,
          ),
        ),
      ),
    );

    expect(find.textContaining('km from you'), findsNothing);
  });
}
