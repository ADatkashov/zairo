import 'package:business_admin/features/salon/data/models/admin_service.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/features/staff_owner/data/models/worker_schedule.dart';
import 'package:business_admin/features/staff_owner/data/staff_owner_api.dart';
import 'package:business_admin/features/staff_owner/presentation/providers/staff_owner_providers.dart';
import 'package:business_admin/features/staff_owner/presentation/widgets/worker_prices_section.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends StaffOwnerApi {
  _FakeApi({required this.enabled}) : super(DioClient(Dio()));

  final bool enabled;
  final Map<String, double> prices = {};
  final List<String> saved = [];

  @override
  Future<WorkforceSettings> settings(String providerId) async =>
      WorkforceSettings(allowWorkerChoice: true, workerPricingEnabled: enabled);

  @override
  Future<Map<String, double>> workerPrices(String providerId, String workerId) async => Map.of(prices);

  @override
  Future<void> setWorkerPrice(String providerId, String workerId, String serviceId, double? price) async {
    saved.add('$serviceId=$price');
    if (price == null) {
      prices.remove(serviceId);
    } else {
      prices[serviceId] = price;
    }
  }
}

Widget _wrap(_FakeApi api) => ProviderScope(
      overrides: [
        staffOwnerApiProvider.overrideWithValue(api),
        providerServicesProvider.overrideWith((ref, key) async => const [
              AdminService(
                id: 'svc1',
                providerId: 'p1',
                title: 'Haircut',
                durationMinutes: 60,
                price: 25,
                currency: 'USD',
                active: true,
              ),
            ]),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(profile: FactoryAppProfile.business),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SingleChildScrollView(child: WorkerPricesSection(providerId: 'p1', workerId: 'w1'))),
      ),
    );

void main() {
  testWidgets('hidden while per-master prices are switched off', (tester) async {
    await tester.pumpWidget(_wrap(_FakeApi(enabled: false)));
    await tester.pumpAndSettle();
    expect(find.text('Prices'), findsNothing);
  });

  testWidgets('owner sets and clears a master\'s own price', (tester) async {
    final api = _FakeApi(enabled: true);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('25 USD'), findsOneWidget);
    expect(find.text('Usual price'), findsOneWidget);

    await tester.tap(find.text('Haircut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '40');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.saved, ['svc1=40.0']);
    expect(find.text('40 USD'), findsOneWidget);

    await tester.tap(find.text('Haircut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use usual price'));
    await tester.pumpAndSettle();
    expect(api.saved.last, 'svc1=null');
    expect(find.text('25 USD'), findsOneWidget);
  });
}
