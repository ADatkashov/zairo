import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/campaign.dart';

/// One campaign, summarized well enough to act on without opening the
/// detail screen -- type, status, trigger, slot (Smart Fill only),
/// candidate/notification progress, outcome, recovered revenue, last
/// update, and a clear next-action chip. Tap opens [CampaignDetailScreen].
class CampaignCard extends StatelessWidget {
  final CampaignDto campaign;
  final VoidCallback onTap;

  const CampaignCard({super.key, required this.campaign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    return FactoryCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                campaignTypeIcon(campaign.type),
                size: 16,
                color: colors.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  campaignTypeLabel(l10n, campaign.type),
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: FactorySpacing.space2),
              Flexible(
                child: FactoryBadge(
                  label: campaignStatusLabel(l10n, campaign.status),
                  variant: campaignStatusVariant(campaign.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space2),
          Text(
            campaign.serviceTitle ?? '—',
            style: textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (campaign.employeeName != null) ...[
            const SizedBox(height: 2),
            Text(
              campaign.employeeName!,
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            campaignTriggerReasonLabel(l10n, campaign.triggerReason),
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          if (campaign.slotStartsAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 14,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    DateFormat.yMMMd(locale)
                        .add_Hm()
                        .format(campaign.slotStartsAt!.toLocal()),
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: FactorySpacing.space3),
          Wrap(
            spacing: FactorySpacing.space3,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    size: 14,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l10n.campaignCardNotifiedProgress(
                        campaign.notifiedCount,
                        campaign.candidateCount,
                      ),
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (campaign.recoveredRevenue != null &&
                  campaign.recoveredRevenue! > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '${l10n.campaignCardRecoveredRevenueLabel}: ',
                        style: textTheme.bodySmall,
                      ),
                    ),
                    FactoryPriceText(
                      amount: campaign.recoveredRevenue!,
                      currencySymbol: campaign.currency,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space3),
          Row(
            children: [
              Expanded(
                child: Text(
                  campaignNextActionLabel(l10n, campaign.nextAction),
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: FactorySpacing.space2),
              Flexible(
                child: Text(
                  l10n.campaignCardUpdatedLabel(
                    DateFormat.yMMMd(locale)
                        .add_Hm()
                        .format(campaign.updatedAt.toLocal()),
                  ),
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData campaignTypeIcon(CampaignType type) => switch (type) {
  CampaignType.smartFill => Icons.bolt_outlined,
  CampaignType.rebook => Icons.event_repeat_outlined,
  CampaignType.reactivation => Icons.replay_outlined,
};

String campaignTypeLabel(AppLocalizations l10n, CampaignType type) =>
    switch (type) {
      CampaignType.smartFill => l10n.campaignTypeSmartFill,
      CampaignType.rebook => l10n.campaignTypeRebook,
      CampaignType.reactivation => l10n.campaignTypeReactivation,
    };

FactoryBadgeVariant campaignStatusVariant(CampaignStatus status) =>
    switch (status) {
      CampaignStatus.active => FactoryBadgeVariant.available,
      CampaignStatus.paused => FactoryBadgeVariant.limited,
      CampaignStatus.completed => FactoryBadgeVariant.verified,
      CampaignStatus.expired => FactoryBadgeVariant.neutral,
      CampaignStatus.failed => FactoryBadgeVariant.error,
      CampaignStatus.cancelled => FactoryBadgeVariant.neutral,
    };

String campaignStatusLabel(AppLocalizations l10n, CampaignStatus status) =>
    switch (status) {
      CampaignStatus.active => l10n.campaignUnifiedStatusActive,
      CampaignStatus.paused => l10n.campaignUnifiedStatusPaused,
      CampaignStatus.completed => l10n.campaignUnifiedStatusCompleted,
      CampaignStatus.expired => l10n.campaignUnifiedStatusExpired,
      CampaignStatus.failed => l10n.campaignUnifiedStatusFailed,
      CampaignStatus.cancelled => l10n.campaignUnifiedStatusCancelled,
    };

String campaignTriggerReasonLabel(
  AppLocalizations l10n,
  CampaignTriggerReason reason,
) => switch (reason) {
  CampaignTriggerReason.bookingCancelled =>
    l10n.campaignTriggerBookingCancelled,
  CampaignTriggerReason.bookingCompleted =>
    l10n.campaignTriggerBookingCompleted,
  CampaignTriggerReason.customerInactive =>
    l10n.campaignTriggerCustomerInactive,
};

String campaignNextActionLabel(
  AppLocalizations l10n,
  CampaignNextAction action,
) => switch (action) {
  CampaignNextAction.none => l10n.campaignNextActionNone,
  CampaignNextAction.waitingForResponse =>
    l10n.campaignNextActionWaitingForResponse,
  CampaignNextAction.pausedByOwner => l10n.campaignNextActionPausedByOwner,
  CampaignNextAction.retryAvailable => l10n.campaignNextActionRetryAvailable,
  CampaignNextAction.viewRecoveredBooking =>
    l10n.campaignNextActionViewRecoveredBooking,
};

String campaignOutcomeLabel(AppLocalizations l10n, CampaignOutcome outcome) =>
    switch (outcome) {
      CampaignOutcome.pending => l10n.campaignOutcomePending,
      CampaignOutcome.recovered => l10n.campaignOutcomeRecovered,
      CampaignOutcome.notRecovered => l10n.campaignOutcomeNotRecovered,
    };

String campaignFailureReasonLabel(
  AppLocalizations l10n,
  CampaignFailureReason reason,
) => switch (reason) {
  CampaignFailureReason.noCandidatesNotified =>
    l10n.campaignFailureNoCandidatesNotified,
  CampaignFailureReason.other => l10n.campaignFailureOther,
};

String campaignActionLabel(AppLocalizations l10n, CampaignActionType action) =>
    switch (action) {
      CampaignActionType.pause => l10n.campaignActionPause,
      CampaignActionType.resume => l10n.campaignActionResume,
      CampaignActionType.cancel => l10n.campaignActionCancel,
      CampaignActionType.retry => l10n.campaignActionRetry,
    };

String campaignTimelineEventLabel(
  AppLocalizations l10n,
  CampaignTimelineEventType type,
) => switch (type) {
  CampaignTimelineEventType.campaignCreated =>
    l10n.timelineEventCampaignCreated,
  CampaignTimelineEventType.candidatesSelected =>
    l10n.timelineEventCandidatesSelected,
  CampaignTimelineEventType.notificationSent =>
    l10n.timelineEventNotificationSent,
  CampaignTimelineEventType.offerAccepted => l10n.timelineEventOfferAccepted,
  CampaignTimelineEventType.bookingCreated => l10n.timelineEventBookingCreated,
  CampaignTimelineEventType.slotRecovered => l10n.timelineEventSlotRecovered,
  CampaignTimelineEventType.campaignExpired =>
    l10n.timelineEventCampaignExpired,
  CampaignTimelineEventType.campaignCancelled =>
    l10n.timelineEventCampaignCancelled,
  CampaignTimelineEventType.campaignCompleted =>
    l10n.timelineEventCampaignCompleted,
};

IconData campaignTimelineEventIcon(CampaignTimelineEventType type) =>
    switch (type) {
      CampaignTimelineEventType.campaignCreated => Icons.flag_outlined,
      CampaignTimelineEventType.candidatesSelected => Icons.people_alt_outlined,
      CampaignTimelineEventType.notificationSent =>
        Icons.notifications_active_outlined,
      CampaignTimelineEventType.offerAccepted => Icons.thumb_up_outlined,
      CampaignTimelineEventType.bookingCreated =>
        Icons.event_available_outlined,
      CampaignTimelineEventType.slotRecovered => Icons.check_circle_outline,
      CampaignTimelineEventType.campaignExpired => Icons.timer_off_outlined,
      CampaignTimelineEventType.campaignCancelled => Icons.cancel_outlined,
      CampaignTimelineEventType.campaignCompleted => Icons.flag_circle_outlined,
    };
