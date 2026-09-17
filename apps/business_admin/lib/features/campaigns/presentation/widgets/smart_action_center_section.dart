import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../salon/data/models/business_analytics.dart';
import '../../../salon/presentation/screens/customer_list_screen.dart';
import '../../data/campaign_center_exception.dart';
import '../../data/models/campaign.dart';
import '../providers/campaign_providers.dart';
import '../screens/campaign_center_screen.dart';
import '../screens/campaign_detail_screen.dart';

/// Extends Business Analytics's Action Center with the cross-campaign,
/// cross-customer signals from GET .../smart-actions -- every item names
/// exactly one real related campaign or customer (see [SmartActionItem]);
/// this never fabricates a count or a generic nudge the way the plain
/// [ActionItem] rows above it do. Caps display at [_maxShown] with a
/// "see all" link into [CampaignCenterScreen] once there's more, so the
/// dashboard doesn't turn into a second campaign list.
class SmartActionCenterSection extends ConsumerWidget {
  final String providerId;

  const SmartActionCenterSection({super.key, required this.providerId});

  static const _maxShown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final ownerUserId = ref.watch(authControllerProvider).value?.id;
    final actionsAsync = ref.watch(smartActionsProvider(providerId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(
          title: l10n.smartActionCenterSectionTitle,
          actionLabel: (actionsAsync.value != null && actionsAsync.value!.items.length > _maxShown && ownerUserId != null)
              ? l10n.smartActionCenterSeeAll
              : null,
          onActionTap: ownerUserId == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CampaignCenterScreen(ownerUserId: ownerUserId)),
                  ),
        ),
        actionsAsync.when(
          data: (data) {
            if (data.items.isEmpty) {
              return Text(
                l10n.smartActionCenterEmpty,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              children: [
                for (final item in data.items.take(_maxShown))
                  _SmartActionCard(providerId: providerId, item: item),
              ],
            );
          },
          loading: () => const FactoryLoadingState(),
          error: (error, _) => FactoryErrorState(
            message: l10n.errorSmartActionsLoadFailed(error.toString()),
            onRetry: () => ref.invalidate(smartActionsProvider(providerId)),
          ),
        ),
      ],
    );
  }
}

class _SmartActionCard extends ConsumerStatefulWidget {
  final String providerId;
  final SmartActionItem item;

  const _SmartActionCard({required this.providerId, required this.item});

  @override
  ConsumerState<_SmartActionCard> createState() => _SmartActionCardState();
}

class _SmartActionCardState extends ConsumerState<_SmartActionCard> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final item = widget.item;
    final showRetry = item.recommendedActions.contains(CampaignActionType.retry) &&
        item.campaignType != null &&
        item.campaignId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
      child: FactoryCard(
        onTap: () => _onTap(context),
        child: Row(
          children: [
            Icon(_iconFor(item.type), size: 20, color: colors.primary),
            const SizedBox(width: FactorySpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_explanationFor(l10n, item.type), style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  FactoryBadge(label: _priorityLabel(l10n, item.priority), variant: _priorityVariant(item.priority)),
                ],
              ),
            ),
            if (showRetry) ...[
              const SizedBox(width: FactorySpacing.space2),
              _isRetrying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(onPressed: _retry, child: Text(l10n.campaignActionRetry)),
            ] else
              Icon(Icons.chevron_right, size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Future<void> _retry() async {
    final l10n = AppLocalizations.of(context)!;
    final item = widget.item;
    final campaignType = item.campaignType;
    final campaignId = item.campaignId;
    if (campaignType == null || campaignId == null) return;

    setState(() => _isRetrying = true);
    try {
      await ref.read(campaignCenterApiProvider).retryCampaign(widget.providerId, campaignType, campaignId);
      if (!mounted) return;
      invalidateCampaignData(ref, (widget.providerId, campaignType, campaignId));
      setState(() => _isRetrying = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRetrying = false);
      final message =
          e is CampaignActionConflictException ? e.localizedMessage(l10n) : l10n.errorCampaignActionFailed(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      ref.invalidate(smartActionsProvider(widget.providerId));
    }
  }

  void _onTap(BuildContext context) {
    final item = widget.item;
    if (item.campaignType != null && item.campaignId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CampaignDetailScreen(
            providerId: widget.providerId,
            type: item.campaignType!,
            campaignId: item.campaignId!,
          ),
        ),
      );
      return;
    }
    if (item.customerId != null) {
      final l10n = AppLocalizations.of(context)!;
      final (retentionStatus, title) = switch (item.type) {
        SmartActionType.rebookingOpportunity => (CustomerRetentionStatus.dueForRebooking, l10n.analyticsDueForRebookingLabel),
        SmartActionType.atRiskCustomer => (CustomerRetentionStatus.atRisk, l10n.analyticsAtRiskCustomersLabel),
        SmartActionType.longInactiveCustomer => (CustomerRetentionStatus.inactive, l10n.analyticsInactiveCustomersLabel),
        _ => (null, l10n.smartActionCenterSectionTitle),
      };
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerListScreen(providerId: widget.providerId, retentionStatus: retentionStatus, title: title),
        ),
      );
    }
  }

  IconData _iconFor(SmartActionType type) => switch (type) {
        SmartActionType.campaignExpiringSoon => Icons.hourglass_bottom_outlined,
        SmartActionType.failedCampaign => Icons.error_outline,
        SmartActionType.retriableCampaign => Icons.replay_outlined,
        SmartActionType.rebookingOpportunity => Icons.event_repeat_outlined,
        SmartActionType.atRiskCustomer => Icons.warning_amber_outlined,
        SmartActionType.longInactiveCustomer => Icons.person_off_outlined,
      };

  String _explanationFor(AppLocalizations l10n, SmartActionType type) => switch (type) {
        SmartActionType.campaignExpiringSoon => l10n.smartActionExplainCampaignExpiringSoon,
        SmartActionType.failedCampaign => l10n.smartActionExplainFailedCampaign,
        SmartActionType.retriableCampaign => l10n.smartActionExplainRetriableCampaign,
        SmartActionType.rebookingOpportunity => l10n.smartActionExplainRebookingOpportunity,
        SmartActionType.atRiskCustomer => l10n.smartActionExplainAtRiskCustomer,
        SmartActionType.longInactiveCustomer => l10n.smartActionExplainLongInactiveCustomer,
      };

  String _priorityLabel(AppLocalizations l10n, SmartActionPriority priority) => switch (priority) {
        SmartActionPriority.high => l10n.smartActionPriorityHigh,
        SmartActionPriority.medium => l10n.smartActionPriorityMedium,
        SmartActionPriority.low => l10n.smartActionPriorityLow,
      };

  FactoryBadgeVariant _priorityVariant(SmartActionPriority priority) => switch (priority) {
        SmartActionPriority.high => FactoryBadgeVariant.error,
        SmartActionPriority.medium => FactoryBadgeVariant.limited,
        SmartActionPriority.low => FactoryBadgeVariant.neutral,
      };
}
