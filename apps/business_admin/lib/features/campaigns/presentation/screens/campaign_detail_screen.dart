import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/campaign_center_exception.dart';
import '../../data/models/campaign.dart';
import '../providers/campaign_providers.dart';
import '../widgets/campaign_card.dart';

/// One campaign in full -- summary, trigger, slot/service/staff info,
/// candidate/notification/offer progress, outcome, a chronological
/// timeline, and the safe-action buttons this campaign actually supports
/// right now (see [CampaignDto.availableActions] -- never inferred, always
/// rendered exactly as the server sent it).
class CampaignDetailScreen extends ConsumerStatefulWidget {
  final String providerId;
  final CampaignType type;
  final String campaignId;

  const CampaignDetailScreen({super.key, required this.providerId, required this.type, required this.campaignId});

  @override
  ConsumerState<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  bool _isSubmitting = false;

  CampaignKey get _key => (widget.providerId, widget.type, widget.campaignId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final detailAsync = ref.watch(campaignDetailProvider(_key));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(
        title: detailAsync.value?.serviceTitle ?? campaignTypeLabel(l10n, widget.type),
      ),
      body: detailAsync.when(
        data: (campaign) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(campaignDetailProvider(_key));
            ref.invalidate(campaignTimelineProvider(_key));
          },
          child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            children: [
              _OverviewCard(campaign: campaign),
              const SizedBox(height: FactorySpacing.space5),
              _ProgressCard(campaign: campaign),
              const SizedBox(height: FactorySpacing.space5),
              _OutcomeCard(campaign: campaign),
              const SizedBox(height: FactorySpacing.space5),
              FactorySectionHeader(title: l10n.campaignDetailSectionTimeline),
              const SizedBox(height: FactorySpacing.space2),
              _TimelineSection(providerKey: _key),
              if (campaign.availableActions.isNotEmpty) ...[
                const SizedBox(height: FactorySpacing.space6),
                _ActionButtons(
                  campaign: campaign,
                  isSubmitting: _isSubmitting,
                  onAction: (action) => _runAction(campaign, action),
                ),
              ],
            ],
          ),
        ),
        loading: () => const FactoryLoadingState(),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorCampaignDetailLoadFailed,
              onRetry: () => ref.invalidate(campaignDetailProvider(_key)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runAction(CampaignDto campaign, CampaignActionType action) async {
    final l10n = AppLocalizations.of(context)!;
    if (action == CampaignActionType.cancel) {
      final confirmed = await showFactoryDialog<bool>(
        context: context,
        title: l10n.campaignCancelConfirmTitle,
        message: l10n.campaignCancelConfirmMessage,
        actions: [
          Builder(
            builder: (dialogContext) => FactoryButton(
              label: l10n.campaignCancelConfirmDismiss,
              variant: FactoryButtonVariant.text,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
          ),
          Builder(
            builder: (dialogContext) => FactoryButton(
              label: l10n.campaignCancelConfirmButton,
              variant: FactoryButtonVariant.danger,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ),
        ],
      );
      if (confirmed != true) return;
    }

    setState(() => _isSubmitting = true);
    final api = ref.read(campaignCenterApiProvider);
    try {
      switch (action) {
        case CampaignActionType.pause:
          await api.pauseCampaign(widget.providerId, widget.type, widget.campaignId);
        case CampaignActionType.resume:
          await api.resumeCampaign(widget.providerId, widget.type, widget.campaignId);
        case CampaignActionType.cancel:
          await api.cancelCampaign(widget.providerId, widget.type, widget.campaignId);
        case CampaignActionType.retry:
          await api.retryCampaign(widget.providerId, widget.type, widget.campaignId);
      }
      if (!mounted) return;
      invalidateCampaignData(ref, _key);
      setState(() => _isSubmitting = false);
    } catch (e) {
      if (!mounted) return;
      // A conflict means the action no longer applies -- refresh so the UI
      // reflects whatever the real current state is, same as any other
      // stale-state recovery in this app.
      invalidateCampaignData(ref, _key);
      setState(() => _isSubmitting = false);
      final message =
          e is CampaignActionConflictException ? e.localizedMessage(l10n) : l10n.errorCampaignActionFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _OverviewCard extends StatelessWidget {
  final CampaignDto campaign;

  const _OverviewCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(campaignTypeIcon(campaign.type), size: 18, color: colors.textTertiary),
              const SizedBox(width: 6),
              Text(campaignTypeLabel(l10n, campaign.type), style: textTheme.labelLarge),
              const Spacer(),
              FactoryBadge(
                label: campaignStatusLabel(l10n, campaign.status),
                variant: campaignStatusVariant(campaign.status),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space3),
          _InfoRow(label: l10n.campaignDetailTriggerLabel, value: campaignTriggerReasonLabel(l10n, campaign.triggerReason)),
          _InfoRow(label: l10n.campaignDetailServiceLabel, value: campaign.serviceTitle ?? '—'),
          if (campaign.employeeName != null) _InfoRow(label: l10n.campaignDetailEmployeeLabel, value: campaign.employeeName!),
          if (campaign.slotStartsAt != null)
            _InfoRow(
              label: l10n.campaignDetailSlotLabel,
              value: DateFormat.yMMMd(locale).add_Hm().format(campaign.slotStartsAt!.toLocal()),
            ),
          _InfoRow(
            label: l10n.campaignDetailCreatedLabel,
            value: DateFormat.yMMMd(locale).add_Hm().format(campaign.createdAt.toLocal()),
          ),
          _InfoRow(
            label: l10n.campaignDetailUpdatedLabel,
            value: DateFormat.yMMMd(locale).add_Hm().format(campaign.updatedAt.toLocal()),
          ),
          if (campaign.completedAt != null)
            _InfoRow(
              label: l10n.campaignDetailCompletedLabel,
              value: DateFormat.yMMMd(locale).add_Hm().format(campaign.completedAt!.toLocal()),
            ),
          _InfoRow(label: l10n.campaignDetailRawStatusLabel, value: campaign.rawStatus),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final CampaignDto campaign;

  const _ProgressCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.campaignDetailSectionProgress),
        const SizedBox(height: FactorySpacing.space2),
        Wrap(
          spacing: FactorySpacing.space3,
          runSpacing: FactorySpacing.space3,
          children: [
            FactoryStatTile(label: l10n.campaignDetailCandidatesLabel, value: '${campaign.candidateCount}'),
            FactoryStatTile(label: l10n.campaignDetailNotifiedLabel, value: '${campaign.notifiedCount}'),
            FactoryStatTile(label: l10n.campaignDetailViewedLabel, value: '${campaign.viewedCount}'),
            FactoryStatTile(label: l10n.campaignDetailAcceptedLabel, value: '${campaign.acceptedCount}'),
          ],
        ),
      ],
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  final CampaignDto campaign;

  const _OutcomeCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.campaignDetailSectionOutcome),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(campaignOutcomeLabel(l10n, campaign.outcome), style: textTheme.titleSmall)),
                  Text(campaignNextActionLabel(l10n, campaign.nextAction), style: textTheme.bodySmall?.copyWith(color: colors.primary)),
                ],
              ),
              if (campaign.recoveredRevenue != null && campaign.recoveredRevenue! > 0) ...[
                const SizedBox(height: FactorySpacing.space2),
                Row(
                  children: [
                    Text('${l10n.campaignDetailRecoveredRevenueLabel}: ', style: textTheme.bodyMedium),
                    FactoryPriceText(amount: campaign.recoveredRevenue!, currencySymbol: campaign.currency, fontSize: 15),
                  ],
                ),
              ],
              if (campaign.recoveredBookingId != null) ...[
                const SizedBox(height: FactorySpacing.space1),
                Text(
                  '${l10n.campaignDetailRecoveredBookingLabel}: ${campaign.recoveredBookingId}',
                  style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                ),
              ],
              if (campaign.failureReason != null) ...[
                const SizedBox(height: FactorySpacing.space2),
                Text(
                  '${l10n.campaignDetailFailureReasonLabel}: ${campaignFailureReasonLabel(l10n, campaign.failureReason!)}',
                  style: textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineSection extends ConsumerWidget {
  final CampaignKey providerKey;

  const _TimelineSection({required this.providerKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final timelineAsync = ref.watch(campaignTimelineProvider(providerKey));

    return timelineAsync.when(
      data: (timeline) {
        if (timeline.events.isEmpty) {
          return Text(
            l10n.campaignTimelineEmpty,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          );
        }
        final locale = Localizations.localeOf(context).toString();
        return FactoryCard(
          child: Column(
            children: [
              for (var i = 0; i < timeline.events.length; i++) ...[
                if (i > 0) Divider(height: FactorySpacing.space4, color: colors.border),
                _TimelineRow(event: timeline.events[i], locale: locale),
              ],
            ],
          ),
        );
      },
      loading: () => const FactoryLoadingState(),
      error: (error, _) => FactoryErrorState(
        message: l10n.errorCampaignTimelineLoadFailed,
        onRetry: () => ref.invalidate(campaignTimelineProvider(providerKey)),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final CampaignTimelineEvent event;
  final String locale;

  const _TimelineRow({required this.event, required this.locale});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(campaignTimelineEventIcon(event.type), size: 18, color: colors.primary),
        const SizedBox(width: FactorySpacing.space3),
        Expanded(child: Text(campaignTimelineEventLabel(l10n, event.type), style: textTheme.bodyMedium)),
        Text(
          DateFormat.yMMMd(locale).add_Hm().format(event.occurredAt.toLocal()),
          style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final CampaignDto campaign;
  final bool isSubmitting;
  final ValueChanged<CampaignActionType> onAction;

  const _ActionButtons({required this.campaign, required this.isSubmitting, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: FactorySpacing.space3,
      runSpacing: FactorySpacing.space3,
      children: [
        for (final action in campaign.availableActions)
          FactoryButton(
            label: campaignActionLabel(l10n, action),
            variant: action == CampaignActionType.cancel ? FactoryButtonVariant.danger : FactoryButtonVariant.secondary,
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : () => onAction(action),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary))),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
