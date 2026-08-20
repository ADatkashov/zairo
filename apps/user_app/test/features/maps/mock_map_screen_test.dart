import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/maps/presentation/screens/mock_map_screen.dart';

void main() {
  testWidgets('shows the provider name, coordinates, and distance', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MockMapScreen(
          providerName: 'Test Salon',
          latitude: 43.2389,
          longitude: 76.8897,
          distanceKm: 2.5,
        ),
      ),
    );

    expect(find.text('Test Salon'), findsOneWidget);
    expect(find.text('Map view placeholder'), findsOneWidget);
    expect(find.text('43.2389, 76.8897'), findsOneWidget);
    expect(find.text('2.5 km from you'), findsOneWidget);
  });

  testWidgets('omits distance when not provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MockMapScreen(
          providerName: 'Test Salon',
          latitude: 43.2389,
          longitude: 76.8897,
        ),
      ),
    );

    expect(find.textContaining('km from you'), findsNothing);
  });
}
