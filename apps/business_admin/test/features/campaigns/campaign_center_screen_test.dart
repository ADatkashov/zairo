import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/campaigns/data/api/campaign_center_api.dart';
import 'package:business_admin/features/campaigns/data/models/campaign.dart';
import 'package:business_admin/features/campaigns/presentation/providers/campaign_providers.dart';
import 'package:business_admin/features/campaigns/presentation/screens/campaign_center_screen.dart';
import 'package:business_admin/features/campaigns/presentation/widgets/campaign_card.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/models/admin_service.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi(this._providers) : super(DioClient(Dio()));

  final List<AdminProvider> _providers;

  @override
  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async => _providers;

  @override
  Future<List<AdminService>> listServices(String providerId, {bool includeInactive = false}) async => const [];
}

class _FakeCampaignCenterApi extends CampaignCenterApi {
  _FakeCampaignCenterApi() : super(DioClient(Dio()));

  FutureOr<CampaignListResponse> Function(CampaignType? type, CampaignStatus? status, int page)? listResponder;
  Object? listError;
  CampaignStatsResponse stats = _stats;
  final List<CampaignStatus?> statusCalls = [];
  final List<CampaignType?> typeCalls = [];

  @override
  Future<CampaignListResponse> fetchCampaigns(
    String providerId, {
    CampaignType? type,
    CampaignStatus? status,
    String? serviceId,
    String? employeeId,
    DateTime? from,
    DateTime? to,
    String? search,
    int page = 0,
    int pageSize = 20,
    bool newestFirst = true,
  }) async {
    statusCalls.add(status);
    typeCalls.add(type);
    if (listError != null) throw listError!;
    return await listResponder!(type, status, page);
  }

  @override
  Future<CampaignStatsResponse> fetchStats(String providerId) async => stats;
}

final _provider = const AdminProvider(id: 'provider-1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE');

final _stats = CampaignStatsResponse(
  providerId: 'provider-1',
  activeCampaigns: 3,
  completedCampaigns: 5,
  failedCampaigns: 1,
  expiredCampaigns: 0,
  cancelledCampaigns: 0,
  recoveredSlots: 5,
  totalRecoveredRevenue: 75000,
  currency: 'KZT',
  conversionRate: 0.5,
  notificationsSent: 20,
  offersAccepted: 5,
  averageCompletionMinutes: 90,
  campaignsRequiringAttention: 2,
);

CampaignDto _campaign(String id, {CampaignStatus status = CampaignStatus.active}) {
  return CampaignDto(
    id: id,
    type: CampaignType.smartFill,
    status: status,
    rawStatus: 'NOTIFYING',
    triggerReason: CampaignTriggerReason.bookingCancelled,
    providerId: 'provider-1',
    serviceId: 'service-1',
    serviceTitle: 'Haircut $id',
    candidateCount: 4,
    notifiedCount: 2,
    viewedCount: 1,
    acceptedCount: 0,
    currency: 'KZT',
    createdAt: DateTime(2026, 9, 13, 9, 0),
    updatedAt: DateTime(2026, 9, 13, 9, 5),
    outcome: CampaignOutcome.pending,
    nextAction: CampaignNextAction.waitingForResponse,
    availableActions: const [CampaignActionType.pause],
  );
}

CampaignListResponse _page(List<CampaignDto> items) =>
    CampaignListResponse(items: items, page: 0, pageSize: 20, totalItems: items.length, totalPages: 1);

Widget _wrap({required _FakeCampaignCenterApi api, List<AdminProvider>? providers}) => ProviderScope(
      overrides: [
        salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi(providers ?? [_provider])),
        campaignCenterApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CampaignCenterScreen(ownerUserId: 'owner-1'),
      ),
    );

void _useTallViewport(WidgetTester tester) {
  // The KPI row, filter chips and search field alone exceed the default
  // 800x600 test surface -- a tall viewport keeps every campaign card
  // mounted (a plain ListView only builds children within its viewport)
  // instead of the test needing to scroll to find them.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('shows a loading indicator while the first page is still in flight', (tester) async {
    _useTallViewport(tester);
    final api = _FakeCampaignCenterApi();
    final completer = Completer<CampaignListResponse>();
    api.listResponder = (_, _, _) => completer.future;

    await tester.pumpWidget(_wrap(api: api));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(_page([]));
    await tester.pumpAndSettle();
  });

  testWidgets('shows an error state with retry when the list fails to load', (tester) async {
    _useTallViewport(tester);
    final api = _FakeCampaignCenterApi();
    api.listError = Exception('network down');

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't load campaigns"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows the empty state when no campaigns match the filters', (tester) async {
    _useTallViewport(tester);
    final api = _FakeCampaignCenterApi();
    api.listResponder = (_, _, _) => _page([]);

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(find.text('No campaigns match these filters.'), findsOneWidget);
  });

  testWidgets('renders one CampaignCard per campaign and the KPI row', (tester) async {
    _useTallViewport(tester);
    final api = _FakeCampaignCenterApi();
    api.listResponder = (_, _, _) => _page([_campaign('c1'), _campaign('c2')]);

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(find.byType(CampaignCard), findsNWidgets(2));
    expect(find.text('Haircut c1'), findsOneWidget);
    expect(find.text('Haircut c2'), findsOneWidget);
    // KPI row, from campaignStatsProvider.
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping a status filter chip re-fetches with that status', (tester) async {
    _useTallViewport(tester);
    final api = _FakeCampaignCenterApi();
    api.listResponder = (_, status, _) => _page([_campaign('c1', status: status ?? CampaignStatus.active)]);

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(api.statusCalls.last, isNull);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(api.statusCalls.last, CampaignStatus.completed);
  });

  testWidgets('type, period and service live behind one Filters button, not three rows of chips', (tester) async {
    _useTallViewport(tester);
    final api = _FakeCampaignCenterApi();
    api.listResponder = (_, _, _) => _page([_campaign('c1')]);

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    // Status stays in view; the rest is in the sheet.
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('All types'), findsNothing);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('the Filters sheet applies a type together, counts it on the button and can be cleared', (tester) async {
    _useTallViewport(tester);
    final api = _FakeCampaignCenterApi();
    api.listResponder = (_, _, _) => _page([_campaign('c1')]);

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();
    expect(api.typeCalls.last, isNull);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('All types'), findsOneWidget);
    await tester.tap(find.text('Rebook'));
    await tester.tap(find.text('This week'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(api.typeCalls.last, CampaignType.rebook);
    expect(find.text('Filters (2)'), findsOneWidget);

    await tester.tap(find.text('Filters (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(api.typeCalls.last, isNull);
    expect(find.text('Filters'), findsOneWidget);
  });

  testWidgets('shows a business picker when the owner has more than one business', (tester) async {
    _useTallViewport(tester);
    final api = _FakeCampaignCenterApi();
    api.listResponder = (_, _, _) => _page([]);
    final second = const AdminProvider(id: 'provider-2', ownerUserId: 'owner-1', name: 'Second Salon', vertical: 'beauty', status: 'ACTIVE');

    await tester.pumpWidget(_wrap(api: api, providers: [_provider, second]));
    await tester.pumpAndSettle();

    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Second Salon'), findsOneWidget);
  });
}
