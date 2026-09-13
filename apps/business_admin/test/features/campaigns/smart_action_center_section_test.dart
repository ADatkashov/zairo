import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/campaigns/data/api/campaign_center_api.dart';
import 'package:business_admin/features/campaigns/data/models/campaign.dart';
import 'package:business_admin/features/campaigns/presentation/providers/campaign_providers.dart';
import 'package:business_admin/features/campaigns/presentation/widgets/smart_action_center_section.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _FakeCampaignCenterApi extends CampaignCenterApi {
  _FakeCampaignCenterApi(this._items) : super(DioClient(Dio()));

  final List<SmartActionItem> _items;
  bool retryCalled = false;

  @override
  Future<SmartActionsResponse> fetchSmartActions(String providerId) async =>
      SmartActionsResponse(providerId: providerId, items: _items);

  @override
  Future<CampaignDto> retryCampaign(String providerId, CampaignType type, String campaignId) async {
    retryCalled = true;
    return _campaignFor(type, campaignId);
  }
}

CampaignDto _campaignFor(CampaignType type, String id) => CampaignDto(
      id: id,
      type: type,
      status: CampaignStatus.active,
      rawStatus: 'SEARCHING',
      triggerReason: CampaignTriggerReason.bookingCancelled,
      providerId: 'provider-1',
      serviceId: 'service-1',
      candidateCount: 0,
      notifiedCount: 0,
      viewedCount: 0,
      acceptedCount: 0,
      createdAt: DateTime(2026, 9, 13),
      updatedAt: DateTime(2026, 9, 13),
      outcome: CampaignOutcome.pending,
      nextAction: CampaignNextAction.none,
      availableActions: const [],
    );

SmartActionItem _item({
  SmartActionType type = SmartActionType.failedCampaign,
  SmartActionPriority priority = SmartActionPriority.high,
  List<CampaignActionType> recommendedActions = const [],
  String? campaignId = 'campaign-1',
  String? customerId,
}) {
  return SmartActionItem(
    type: type,
    priority: priority,
    providerId: 'provider-1',
    campaignType: campaignId != null ? CampaignType.smartFill : null,
    campaignId: campaignId,
    customerId: customerId,
    observedAt: DateTime(2026, 9, 13, 10),
    recommendedActions: recommendedActions,
  );
}

class _LoggedInOwnerController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'owner-1', email: 'owner@example.com', displayName: 'Jamie Owner', role: 'PROVIDER_OWNER');
  }
}

Widget _wrap(_FakeCampaignCenterApi api) => ProviderScope(
      overrides: [
        campaignCenterApiProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(_LoggedInOwnerController.new),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: const SmartActionCenterSection(providerId: 'provider-1'))),
      ),
    );

void main() {
  testWidgets('shows the empty state when nothing needs attention', (tester) async {
    await tester.pumpWidget(_wrap(_FakeCampaignCenterApi(const [])));
    await tester.pumpAndSettle();

    expect(find.text('Nothing needs attention right now.'), findsOneWidget);
  });

  testWidgets('shows a short explanation and priority badge for each item', (tester) async {
    final api = _FakeCampaignCenterApi([
      _item(type: SmartActionType.failedCampaign, priority: SmartActionPriority.high),
      _item(
        type: SmartActionType.retriableCampaign,
        priority: SmartActionPriority.medium,
        recommendedActions: const [CampaignActionType.retry],
        campaignId: 'campaign-2',
      ),
    ]);

    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    expect(find.text("A campaign couldn't recover this slot."), findsOneWidget);
    expect(find.text('High priority'), findsOneWidget);
    expect(find.text('This expired campaign can be retried — the slot is still open.'), findsOneWidget);
    expect(find.text('Medium priority'), findsOneWidget);
  });

  testWidgets('shows a Retry button only when RETRY is a recommended action, and it calls the API', (tester) async {
    final api = _FakeCampaignCenterApi([
      _item(type: SmartActionType.failedCampaign, recommendedActions: const []),
      _item(
        type: SmartActionType.retriableCampaign,
        recommendedActions: const [CampaignActionType.retry],
        campaignId: 'campaign-2',
      ),
    ]);

    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(api.retryCalled, isTrue);
  });

  testWidgets('caps display at 5 items and shows a See all link', (tester) async {
    final items = List.generate(7, (i) => _item(campaignId: 'campaign-$i'));
    final api = _FakeCampaignCenterApi(items);

    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    expect(find.text('See all'), findsOneWidget);
  });
}
