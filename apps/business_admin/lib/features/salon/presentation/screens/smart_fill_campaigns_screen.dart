import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/salon_providers.dart';

/// The Action Center's "Smart Fill opportunity" drill-down — every campaign
/// still actively trying to recover a cancelled slot for this business,
/// read-only (no campaign-level actions exist yet in this app).
class SmartFillCampaignsScreen extends ConsumerWidget {
  final String providerId;

  const SmartFillCampaignsScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final campaignsAsync = ref.watch(activeSmartFillCampaignsProvider(providerId));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.smartFillCampaignsScreenTitle),
      body: campaignsAsync.when(
        data: (campaigns) {
          if (campaigns.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(FactorySpacing.space6),
                child: Text(
                  l10n.smartFillCampaignsEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                ),
              ),
            );
          }
          final locale = Localizations.localeOf(context).toString();
          return ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            itemCount: campaigns.length,
            separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return FactoryCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat.yMMMd(locale).add_Hm().format(campaign.slotStartsAt.toLocal()),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.smartFillCampaignCandidatesNotified(campaign.candidatesNotified),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.space3),
                    FactoryBadge(
                      label: _statusLabel(l10n, campaign.status),
                      variant: campaign.status == 'CREATED' ? FactoryBadgeVariant.neutral : FactoryBadgeVariant.limited,
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const FactoryLoadingState(),
        error: (error, _) => FactoryErrorState(
          message: l10n.errorAnalyticsLoadFailed(error.toString()),
          onRetry: () => ref.invalidate(activeSmartFillCampaignsProvider(providerId)),
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
    'CREATED' => l10n.campaignStatusCreated,
    'SEARCHING' => l10n.campaignStatusSearching,
    'NOTIFYING' => l10n.campaignStatusNotifying,
    _ => status,
  };
}
