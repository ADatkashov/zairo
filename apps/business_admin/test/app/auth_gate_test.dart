import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/app/auth_gate.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/beauty/data/beauty_admin_api.dart';
import 'package:business_admin/features/beauty/data/models/admin_master.dart';
import 'package:business_admin/features/beauty/presentation/providers/beauty_admin_providers.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi() : super(DioClient(Dio()));

  @override
  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async => const [];

  @override
  Future<List<AdminProvider>> listProvidersByStatus(String status) async => const [];
}

class _FakeBeautyAdminApi extends BeautyAdminApi {
  _FakeBeautyAdminApi() : super(DioClient(Dio()));

  @override
  Future<List<AdminMaster>> listMasters(String providerId, {bool includeInactive = false}) async => const [];
}

class _LoggedInController extends AuthController {
  _LoggedInController(this.role);

  final String role;

  @override
  Future<UserSummary?> build() async {
    return UserSummary(id: 'user-1', email: 'user@example.com', displayName: 'Test User', role: role);
  }
}

void main() {
  testWidgets('routes an ADMIN straight to the moderation screen, not the salon dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi()),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
          authControllerProvider.overrideWith(() => _LoggedInController('ADMIN')),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Salon moderation'), findsOneWidget);
    expect(find.text('Hi, Test User'), findsNothing);
  });

  testWidgets('routes a PROVIDER_OWNER to their salon dashboard, not moderation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi()),
          beautyAdminApiProvider.overrideWithValue(_FakeBeautyAdminApi()),
          authControllerProvider.overrideWith(() => _LoggedInController('PROVIDER_OWNER')),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hi, Test User'), findsOneWidget);
    expect(find.text('Salon moderation'), findsNothing);
  });
}
