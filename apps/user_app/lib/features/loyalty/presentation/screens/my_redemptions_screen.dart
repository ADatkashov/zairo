import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logged_out_gate.dart';
import '../../data/loyalty_exception.dart';
import '../../data/models/loyalty.dart';
import '../providers/loyalty_providers.dart';

/// Every redemption code the caller holds, across every business --
/// GET /loyalty/redemptions. Reached from Profile (see ProfileScreen), same
/// "own identity, no key needed" shape as MyRewardsScreen.
class MyRedemptionsScreen extends ConsumerWidget {
  const MyRedemptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.loyaltyRedemptionsTitle),
      body: authState.when(
        data: (user) => user == null
            ? LoggedOutGate(icon: Symbols.confirmation_number_rounded, message: l10n.loyaltyRedemptionsLoggedOutPrompt)
            : const _RedemptionsBody(),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric,
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _RedemptionsBody extends ConsumerStatefulWidget {
  const _RedemptionsBody();

  @override
  ConsumerState<_RedemptionsBody> createState() => _RedemptionsBodyState();
}

class _RedemptionsBodyState extends ConsumerState<_RedemptionsBody> {
  int _page = 0;
  final List<LoyaltyRedemption> _items = [];
  final Set<int> _loadedPages = {};
  int _totalPages = 1;
  String? _cancellingId;

  void _replaceItem(LoyaltyRedemption updated) {
    setState(() {
      final index = _items.indexWhere((r) => r.id == updated.id);
      if (index != -1) _items[index] = updated;
    });
  }

  Future<void> _cancel(LoyaltyRedemption redemption) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.loyaltyRedemptionCancelConfirmTitle,
      message: l10n.loyaltyRedemptionCancelConfirmMessage(redemption.pointsSpent),
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.loyaltyRedemptionCancelKeepButton,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.loyaltyRedemptionCancelConfirmButton,
            variant: FactoryButtonVariant.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _cancellingId = redemption.id);
    try {
      final updated = await ref.read(loyaltyApiProvider).cancelRedemption(redemption.id);
      _replaceItem(updated);
      invalidateLoyaltyData(ref, redemption.providerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.loyaltyRedemptionCancelledMessage)));
    } on LoyaltyException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorLoyaltyCancelGeneric)));
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pageAsync = ref.watch(myRedemptionsProvider(_page));

    ref.listen(myRedemptionsProvider(_page), (previous, next) {
      next.whenData((resp) {
        if (_loadedPages.add(resp.number)) {
          setState(() {
            _items.addAll(resp.content);
            _totalPages = resp.totalPages;
          });
        }
      });
    });

    if (_items.isEmpty) {
      return pageAsync.when(
        data: (resp) => resp.content.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(FactorySpacing.space6),
                  child: FactoryEmptyState(
                    icon: Symbols.confirmation_number_rounded,
                    title: l10n.loyaltyRedemptionsEmptyTitle,
                    message: l10n.loyaltyRedemptionsEmptyMessage,
                  ),
                ),
              )
            : const FactoryLoadingState(),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorLoyaltyRedemptionsLoadFailed,
              onRetry: () => ref.invalidate(myRedemptionsProvider(_page)),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      itemCount: _items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          if (_page + 1 >= _totalPages) return const SizedBox.shrink();
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space4),
              child: pageAsync.isLoading
                  ? const CircularProgressIndicator(strokeWidth: 2.5)
                  : FactoryButton(
                      label: l10n.loyaltyListLoadMore,
                      variant: FactoryButtonVariant.secondary,
                      onPressed: () => setState(() => _page += 1),
                    ),
            ),
          );
        }
        final redemption = _items[index];
        return _RedemptionCard(
          redemption: redemption,
          isCancelling: _cancellingId == redemption.id,
          onCancel: _cancellingId == null ? () => _cancel(redemption) : null,
        );
      },
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  final LoyaltyRedemption redemption;
  final bool isCancelling;
  final VoidCallback? onCancel;

  const _RedemptionCard({required this.redemption, required this.isCancelling, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final (badgeLabel, badgeVariant) = switch (redemption.status) {
      LoyaltyRedemptionStatus.active => (l10n.loyaltyRedemptionStatusActive, FactoryBadgeVariant.available),
      LoyaltyRedemptionStatus.applied => (l10n.loyaltyRedemptionStatusApplied, FactoryBadgeVariant.verified),
      LoyaltyRedemptionStatus.cancelled => (l10n.loyaltyRedemptionStatusCancelled, FactoryBadgeVariant.neutral),
      LoyaltyRedemptionStatus.expired => (l10n.loyaltyRedemptionStatusExpired, FactoryBadgeVariant.error),
    };

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(redemption.rewardName, style: textTheme.titleSmall),
                    if (redemption.providerName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        redemption.providerName!,
                        style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              FactoryBadge(label: badgeLabel, variant: badgeVariant),
            ],
          ),
          const SizedBox(height: FactorySpacing.space3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space3),
            decoration: BoxDecoration(color: colors.surfaceAlt, borderRadius: FactoryRadius.mdRadius),
            child: Center(
              child: SelectableText(
                redemption.code,
                style: FactoryTypography.mono(size: 22, weight: FontWeight.w800, color: colors.text),
              ),
            ),
          ),
          const SizedBox(height: FactorySpacing.space2),
          Text(
            l10n.loyaltyRedemptionCreatedOn(formatMonthDayTime(l10n, redemption.createdAt.toLocal())),
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
          if (redemption.appliedAt != null)
            Text(
              l10n.loyaltyRedemptionAppliedOn(formatMonthDayTime(l10n, redemption.appliedAt!.toLocal())),
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
          if (redemption.status == LoyaltyRedemptionStatus.active) ...[
            const SizedBox(height: FactorySpacing.space3),
            FactoryButton(
              label: l10n.loyaltyRedemptionCancelButton,
              variant: FactoryButtonVariant.textDanger,
              isLoading: isCancelling,
              onPressed: onCancel,
            ),
          ],
        ],
      ),
    );
  }
}
