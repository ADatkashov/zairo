import 'package:business_admin/features/staff_owner/data/models/needs_attention.dart';
import 'package:business_admin/features/staff_owner/data/staff_owner_api.dart';
import 'package:business_admin/features/staff_owner/presentation/providers/staff_owner_providers.dart';
import 'package:business_admin/features/staff_owner/presentation/widgets/needs_attention_section.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NeedsAttentionItem _item(String bookingId) => NeedsAttentionItem(
      bookingId: bookingId,
      status: 'CONFIRMED',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      endsAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
      serviceTitle: 'Haircut',
      customerName: 'Dana',
      customerPhone: '+77001112233',
      totalPrice: 25,
      currency: 'USD',
      staffId: 's1',
      staffName: 'Aigerim',
      reason: 'STAFF_CANNOT_ATTEND',
      staffNote: 'Sick leave',
      requestedAt: DateTime.now(),
    );

class _FakeStaffOwnerApi extends StaffOwnerApi {
  _FakeStaffOwnerApi(this.items) : super(DioClient(Dio()));

  List<NeedsAttentionItem> items;
  final List<String> cancelled = [];

  @override
  Future<List<NeedsAttentionItem>> needsAttention(String providerId) async => items;

  @override
  Future<void> cancelAppointment(String providerId, String bookingId, {String? reason}) async {
    cancelled.add('$providerId/$bookingId');
    items = [];
  }
}

Widget _wrap(_FakeStaffOwnerApi api) => ProviderScope(
      overrides: [staffOwnerApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: factoryLightTheme(profile: FactoryAppProfile.business),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SingleChildScrollView(child: NeedsAttentionSection(providerId: 'p1'))),
      ),
    );

void main() {
  testWidgets('shows nothing when no appointment needs a decision', (tester) async {
    await tester.pumpWidget(_wrap(_FakeStaffOwnerApi([])));
    await tester.pumpAndSettle();

    expect(find.text('Needs your decision'), findsNothing);
  });

  testWidgets('lists the request and lets the owner cancel after confirming', (tester) async {
    final api = _FakeStaffOwnerApi([_item('b1')]);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    expect(find.text('Needs your decision'), findsOneWidget);
    expect(find.text("Aigerim can't attend"), findsOneWidget);
    expect(find.textContaining('Dana'), findsOneWidget);

    await tester.tap(find.text('Cancel and refund'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this appointment?'), findsOneWidget);
    // The dialog's confirm button and the card's own button share the label; the dialog one is the last.
    await tester.tap(find.text('Cancel and refund').last);
    await tester.pumpAndSettle();

    expect(api.cancelled, ['p1/b1']);
    expect(find.text('Needs your decision'), findsNothing);
  });
}
