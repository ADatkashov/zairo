import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_admin_exception.dart';
import '../../data/models/loyalty_reward.dart';
import '../providers/loyalty_admin_providers.dart';
import '../widgets/loyalty_reward_card.dart';
import 'loyalty_reward_form_screen.dart';

/// The reward catalog -- active and inactive rewards both visible (the
/// backend list endpoint always includes both), each clearly badged, with
/// activate/deactivate/delete actions and a floating "add" entry point into
/// [LoyaltyRewardFormScreen].
class LoyaltyRewardsScreen extends ConsumerWidget {
  final String providerId;

  const LoyaltyRewardsScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final rewardsAsync = ref.watch(loyaltyRewardsProvider(providerId));

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref, existing: null),
        icon: const Icon(Icons.add),
        label: Text(l10n.loyaltyRewardAddButton),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(loyaltyRewardsProvider(providerId)),
        child: rewardsAsync.when(
          data: (rewards) {
            if (rewards.isEmpty) {
              return ListView(
                children: [
                  FactoryEmptyState(
                    icon: Icons.card_giftcard_outlined,
                    title: l10n.loyaltyRewardsEmptyTitle,
                    message: l10n.loyaltyRewardsEmptyMessage,
                    actionLabel: l10n.loyaltyRewardAddButton,
                    onAction: () => _openForm(context, ref, existing: null),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                FactorySpacing.space4,
                FactorySpacing.space4,
                FactorySpacing.space4,
                FactorySpacing.space8 + FactorySpacing.space6,
              ),
              itemCount: rewards.length,
              separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
              itemBuilder: (context, index) {
                final reward = rewards[index];
                return _RewardTile(
                  reward: reward,
                  onEdit: () => _openForm(context, ref, existing: reward),
                  onToggleActive: () => _toggleActive(context, ref, reward),
                  onDelete: () => _delete(context, ref, reward),
                );
              },
            );
          },
          loading: () => const FactoryLoadingState(),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              child: FactoryErrorState(
                message: l10n.errorLoyaltyRewardsLoadFailed,
                onRetry: () => ref.invalidate(loyaltyRewardsProvider(providerId)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, {required LoyaltyReward? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoyaltyRewardFormScreen(providerId: providerId, existing: existing)),
    );
    if (saved == true) invalidateLoyaltyRewards(ref, providerId);
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, LoyaltyReward reward) async {
    final l10n = AppLocalizations.of(context)!;
    final api = ref.read(loyaltyAdminApiProvider);
    try {
      if (reward.active) {
        await api.deactivateReward(providerId, reward.id!);
      } else {
        await api.activateReward(providerId, reward.id!);
      }
      invalidateLoyaltyRewards(ref, providerId);
    } catch (e) {
      if (!context.mounted) return;
      final message = e is LoyaltyAdminException ? e.localizedMessage(l10n) : l10n.errorLoyaltyActionFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, LoyaltyReward reward) async {
    final l10n = AppLocalizations.of(context)!;
    // A reward with redemption history can't be deleted (409) -- offer
    // Deactivate up front instead of letting the owner hit that wall.
    if (reward.redemptionsCount > 0) {
      final deactivateInstead = await showFactoryDialog<bool>(
        context: context,
        title: l10n.loyaltyRewardDeleteBlockedTitle,
        message: l10n.loyaltyRewardDeleteBlockedMessage(reward.redemptionsCount),
        actions: [
          Builder(
            builder: (dialogContext) => FactoryButton(
              label: l10n.cancelButton,
              variant: FactoryButtonVariant.text,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
          ),
          if (reward.active)
            Builder(
              builder: (dialogContext) => FactoryButton(
                label: l10n.loyaltyRewardDeactivateButton,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ),
        ],
      );
      if (deactivateInstead == true && context.mounted) await _toggleActive(context, ref, reward);
      return;
    }

    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.loyaltyRewardDeleteConfirmTitle,
      message: l10n.loyaltyRewardDeleteConfirmMessage(reward.name),
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.cancelButton,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.loyaltyRewardDeleteButton,
            variant: FactoryButtonVariant.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true) return;

    try {
      await ref.read(loyaltyAdminApiProvider).deleteReward(providerId, reward.id!);
      invalidateLoyaltyRewards(ref, providerId);
    } catch (e) {
      if (!context.mounted) return;
      final message = e is LoyaltyAdminException ? e.localizedMessage(l10n) : l10n.errorLoyaltyActionFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _RewardTile extends StatelessWidget {
  final LoyaltyReward reward;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _RewardTile({required this.reward, required this.onEdit, required this.onToggleActive, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoyaltyRewardCard(reward: reward, onTap: onEdit),
        Wrap(
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: onToggleActive,
              child: Text(reward.active ? l10n.loyaltyRewardDeactivateButton : l10n.loyaltyRewardActivateButton),
            ),
            TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: Text(l10n.loyaltyRewardDeleteButton),
            ),
          ],
        ),
      ],
    );
  }
}
