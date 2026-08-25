import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/moderation/presentation/screens/moderation_screen.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi(this._pending) : super(DioClient(Dio()));

  final List<AdminProvider> _pending;
  Map<String, dynamic>? lastStatusCall;

  @override
  Future<List<AdminProvider>> listProvidersByStatus(String status) async {
    return _pending.where((p) => p.status == status).toList();
  }

  @override
  Future<AdminProvider> updateProviderStatus({required String providerId, required String status}) async {
    lastStatusCall = {'providerId': providerId, 'status': status};
    final index = _pending.indexWhere((p) => p.id == providerId);
    final updated = AdminProvider(
      id: _pending[index].id,
      ownerUserId: _pending[index].ownerUserId,
      name: _pending[index].name,
      vertical: _pending[index].vertical,
      status: status,
    );
    _pending[index] = updated;
    return updated;
  }
}

void main() {
  testWidgets('shows salons awaiting approval and lets an admin approve or suspend them', (tester) async {
    final fakeApi = _FakeSalonAdminApi([
      const AdminProvider(
        id: 'p1',
        ownerUserId: 'owner-1',
        name: 'Glow Salon',
        vertical: 'beauty',
        status: 'PENDING',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [salonAdminApiProvider.overrideWithValue(fakeApi)],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ModerationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Beauty'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastStatusCall, {'providerId': 'p1', 'status': 'ACTIVE'});
    // No longer PENDING, so it drops out of the moderation queue.
    expect(find.text('No businesses awaiting approval'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing is pending', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi([]))],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ModerationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No businesses awaiting approval'), findsOneWidget);
  });
}
