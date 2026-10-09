import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/core/provider_grid.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/booking/presentation/widgets/booking_payment_summary.dart';
import 'package:zairo/l10n/app_localizations.dart';

/// A small phone with large system text: nothing may overflow.
Future<void> _pumpNarrow(WidgetTester tester, Widget child, {Size size = const Size(320, 640)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: app!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

Booking _booking({double? deposit}) => Booking(
  id: 'b1',
  userId: 'u1',
  serviceId: 's1',
  availabilitySlotId: 'slot1',
  status: 'PENDING_PAYMENT',
  totalPrice: 12000,
  depositAmount: deposit,
  createdAt: DateTime(2026, 1, 1, 9),
);

void main() {
  testWidgets('booking amounts fit with and without a deposit', (tester) async {
    await _pumpNarrow(
      tester,
      Column(children: [BookingAmounts(booking: _booking()), BookingAmounts(booking: _booking(deposit: 3000))]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter chips with long labels shrink instead of overflowing', (tester) async {
    await _pumpNarrow(
      tester,
      const Row(children: [Expanded(child: FactoryChip(label: 'Очень длинное название фильтра для проверки'))]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty state in a short space scrolls instead of overflowing', (tester) async {
    await _pumpNarrow(
      tester,
      const SizedBox(
        height: 120,
        child: FactoryEmptyState(
          icon: Icons.search,
          title: 'Ничего не найдено',
          message: 'Попробуйте изменить фильтры или запрос поиска',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the provider grid is taller on a narrow phone and with larger text', (tester) async {
    late double narrowLarge;
    late double wideNormal;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
          child: Builder(
            builder: (context) {
              narrowLarge = providerGridAspectRatio(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(412, 900)),
          child: Builder(
            builder: (context) {
              wideNormal = providerGridAspectRatio(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(wideNormal, 0.78);
    expect(narrowLarge, lessThan(wideNormal));
  });
}
