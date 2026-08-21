import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/payments/data/models/payment.dart';
import 'package:zairo/features/payments/data/payments_api.dart';
import 'package:zairo/features/payments/presentation/providers/payments_providers.dart';
import 'package:zairo/features/payments/presentation/widgets/payment_status_chip.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakePaymentsApi extends PaymentsApi {
  _FakePaymentsApi(this._payment) : super(DioClient(Dio()));

  final Payment? _payment;

  @override
  Future<Payment?> getPayment(String bookingId) async => _payment;
}

void main() {
  testWidgets('shows nothing when there is no payment yet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentsApiProvider.overrideWithValue(_FakePaymentsApi(null))],
        child: const MaterialApp(home: Scaffold(body: PaymentStatusChip(bookingId: 'booking-1'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('shows the payment status once loaded', (tester) async {
    final payment = Payment(
      id: 'payment-1',
      bookingId: 'booking-1',
      amount: 30,
      currency: 'USD',
      status: 'SUCCEEDED',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentsApiProvider.overrideWithValue(_FakePaymentsApi(payment))],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: PaymentStatusChip(bookingId: 'booking-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment: Succeeded'), findsOneWidget);
  });
}
