import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/salon/data/models/business_analytics.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/features/salon/presentation/screens/customer_list_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi() : super(DioClient(Dio()));

  @override
  Future<List<CustomerListItem>> fetchCustomerList(
    String providerId, {
    CustomerRetentionStatus? retentionStatus,
  }) async => const [
    CustomerListItem(
      userId: 'u1',
      displayName: 'Aigerim Nur',
      email: 'aigerim@example.com',
      retentionStatus: CustomerRetentionStatus.active,
      totalSpent: 120,
    ),
    CustomerListItem(
      userId: 'u2',
      displayName: 'Dana K.',
      email: 'dana@mail.kz',
      retentionStatus: CustomerRetentionStatus.atRisk,
      totalSpent: 40,
      noShows: 3,
    ),
  ];
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi())],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CustomerListScreen(providerId: 'p1', title: 'Customers'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('typing narrows the list by name or email, clearing restores it', (tester) async {
    await _pump(tester);
    expect(find.text('Aigerim Nur'), findsOneWidget);
    expect(find.text('Dana K.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mail.kz');
    await tester.pump();
    expect(find.text('Aigerim Nur'), findsNothing);
    expect(find.text('Dana K.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No customers match your search.'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('Aigerim Nur'), findsOneWidget);
    expect(find.text('Dana K.'), findsOneWidget);
  });

  testWidgets('only a customer who missed visits gets a no-show note', (tester) async {
    await _pump(tester);
    expect(find.text('No-shows: 3'), findsOneWidget);
    expect(find.textContaining('No-shows'), findsOneWidget);
  });
}
