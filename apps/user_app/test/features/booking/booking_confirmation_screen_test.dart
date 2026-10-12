import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/screens/booking_confirmation_screen.dart';
import 'package:zairo/features/discovery/data/models/service_summary.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/l10n/app_localizations.dart';

Widget _screen({String vertical = 'beauty', bool disableAnimations = false}) {
  return ProviderScope(
    overrides: [paymentForBookingProvider.overrideWith((ref, id) async => null)],
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations, size: const Size(390, 844)),
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookingConfirmationScreen(
          booking: Booking(
            id: 'b1',
            userId: 'u1',
            serviceId: 's1',
            availabilitySlotId: 'a1',
            status: 'CONFIRMED',
            totalPrice: 12000,
            depositAmount: 2400,
            remainingAmount: 9600,
            createdAt: DateTime(2026, 10, 12),
          ),
          providerId: 'p1',
          providerName: 'Aigerim Beauty Studio',
          providerVertical: vertical,
          service: const ServiceSummary(id: 's1', title: 'Haircut', durationMinutes: 60, price: 12000, currency: 'KZT'),
          slotStartsAt: DateTime(2026, 10, 14, 14, 30),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows what was booked, with whom and when', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    expect(find.text('Aigerim Beauty Studio'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.content_cut_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the vertical picks the service icon', (tester) async {
    await tester.pumpWidget(_screen(vertical: 'auto'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.directions_car_filled_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.content_cut_rounded), findsNothing);
  });

  testWidgets('with reduce motion on, the success mark is fully shown at once', (tester) async {
    await tester.pumpWidget(_screen(disableAnimations: true));
    // One frame, no settling: the animation duration resolves to zero.
    await tester.pump();

    final opacity = tester.widget<Opacity>(find.ancestor(of: find.byIcon(Symbols.check_rounded), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 1);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
