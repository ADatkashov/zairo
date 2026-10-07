import 'package:business_admin/features/salon/data/models/schedule_entry.dart';
import 'package:business_admin/features/staff_owner/data/staff_owner_api.dart';
import 'package:business_admin/features/staff_owner/presentation/providers/staff_owner_providers.dart';
import 'package:business_admin/features/staff_owner/presentation/widgets/no_show_correction.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends StaffOwnerApi {
  _FakeApi() : super(DioClient(Dio()));

  final List<String> attended = [];

  @override
  Future<void> markAttended(String providerId, String bookingId) async => attended.add('$providerId/$bookingId');
}

void main() {
  testWidgets('a no-show can be corrected after confirming', (tester) async {
    final api = _FakeApi();
    var corrected = 0;
    final item = AgendaItem(
      entry: ScheduleEntry(
        bookingId: 'b1',
        serviceId: 's1',
        availabilitySlotId: 'slot',
        status: 'NO_SHOW',
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(hours: 1)),
        totalPrice: 25,
      ),
      providerId: 'p1',
      providerName: 'Salon',
      serviceTitle: 'Haircut',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [staffOwnerApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: factoryLightTheme(profile: FactoryAppProfile.business),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NoShowCorrection(item: item, onCorrected: () => corrected++, child: const Text('row')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('row'));
    await tester.pumpAndSettle();
    expect(find.text('Did the customer come?'), findsOneWidget);
    await tester.tap(find.text('They came'));
    await tester.pumpAndSettle();

    expect(api.attended, ['p1/b1']);
    expect(corrected, 1);
  });
}
