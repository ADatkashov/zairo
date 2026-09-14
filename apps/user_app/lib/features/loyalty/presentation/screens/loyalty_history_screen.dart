import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/loyalty.dart';
import '../providers/loyalty_providers.dart';

/// One business's full, unfiltered points ledger -- every EARNED/BONUS/
/// REDEEMED/EXPIRED/REFUND/ADJUSTMENT/REVERSAL row, newest first. Pages are
/// accumulated into local state as they arrive rather than the provider
/// owning that list, same division of responsibility as Campaign Center's
/// campaignListProvider (see that screen's own doc comment).
class LoyaltyHistoryScreen extends ConsumerStatefulWidget {
  final String providerId;
  final String? providerName;

  const LoyaltyHistoryScreen({super.key, required this.providerId, this.providerName});

  @override
  ConsumerState<LoyaltyHistoryScreen> createState() => _LoyaltyHistoryScreenState();
}

class _LoyaltyHistoryScreenState extends ConsumerState<LoyaltyHistoryScreen> {
  int _page = 0;
  final List<LoyaltyTransaction> _items = [];
  final Set<int> _loadedPages = {};
  int _totalPages = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final key = (widget.providerId, _page);
    final pageAsync = ref.watch(loyaltyHistoryProvider(key));

    ref.listen(loyaltyHistoryProvider(key), (previous, next) {
      next.whenData((resp) {
        if (_loadedPages.add(resp.number)) {
          setState(() {
            _items.addAll(resp.content);
            _totalPages = resp.totalPages;
          });
        }
      });
    });

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.loyaltyHistoryTitle),
      body: _items.isEmpty
          ? pageAsync.when(
              data: (resp) => resp.content.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(FactorySpacing.space6),
                        child: FactoryEmptyState(
                          icon: Symbols.receipt_long_rounded,
                          title: l10n.loyaltyHistoryEmptyTitle,
                          message: l10n.loyaltyHistoryEmptyMessage,
                        ),
                      ),
                    )
                  : const FactoryLoadingState(),
              loading: () => const FactoryLoadingState(),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(FactorySpacing.space4),
                  child: FactoryErrorState(
                    message: l10n.errorLoyaltyHistoryLoadFailed,
                    onRetry: () => ref.invalidate(loyaltyHistoryProvider(key)),
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              itemCount: _items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: FactorySpacing.space2),
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
                return _TransactionRow(transaction: _items[index]);
              },
            ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final LoyaltyTransaction transaction;

  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final isGain = transaction.pointsDelta > 0;
    final deltaColor = isGain
        ? colors.success
        : (transaction.pointsDelta < 0 ? colors.error : colors.textTertiary);

    return FactoryCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color.alphaBlend(deltaColor.withValues(alpha: 0.14), colors.surface),
              shape: BoxShape.circle,
            ),
            child: Icon(isGain ? Symbols.add_rounded : Symbols.remove_rounded, size: 18, color: deltaColor),
          ),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_typeLabel(l10n), style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: FactorySpacing.space2),
                    Text(
                      formatMonthDayTime(l10n, transaction.createdAt.toLocal()),
                      style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.reason,
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                if (transaction.expiresAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.loyaltyTransactionExpiresOn(formatMonthDayTime(l10n, transaction.expiresAt!.toLocal())),
                    style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: FactorySpacing.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isGain ? '+' : ''}${transaction.pointsDelta}',
                style: textTheme.titleSmall?.copyWith(color: deltaColor, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.loyaltyTransactionBalanceAfter(transaction.balanceAfter),
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n) => switch (transaction.type) {
        LoyaltyTransactionType.earned => l10n.loyaltyTxTypeEarned,
        LoyaltyTransactionType.bonus => l10n.loyaltyTxTypeBonus,
        LoyaltyTransactionType.redeemed => l10n.loyaltyTxTypeRedeemed,
        LoyaltyTransactionType.expired => l10n.loyaltyTxTypeExpired,
        LoyaltyTransactionType.refund => l10n.loyaltyTxTypeRefund,
        LoyaltyTransactionType.adjustment => l10n.loyaltyTxTypeAdjustment,
        LoyaltyTransactionType.reversal => l10n.loyaltyTxTypeReversal,
      };
}
