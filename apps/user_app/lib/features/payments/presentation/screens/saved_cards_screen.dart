import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/saved_card.dart';
import '../providers/payments_providers.dart';

/// The customer's saved cards: a switch for saving the card at the next online
/// payment (a provider can only create a reusable card during a real payment),
/// and the cards themselves, each removable.
class SavedCardsScreen extends ConsumerWidget {
  const SavedCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final cardsAsync = ref.watch(savedCardsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.paymentCardsTitle),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.paymentCardsLoadFailed,
              onRetry: () => ref.invalidate(savedCardsProvider),
            ),
          ),
        ),
        data: (info) => ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            Text(
              l10n.paymentCardsIntro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: FactorySpacing.space4),
            FactoryCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.paymentCardsSaveSwitch, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: FactorySpacing.space1),
                        Text(
                          l10n.paymentCardsSaveSwitchHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: info.saveOnNextPayment,
                    onChanged: (value) => _setSave(context, ref, value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FactorySpacing.space4),
            if (info.cards.isEmpty)
              // There is no "add a card" form: a card is saved while paying. Say that, instead of a bare grey line.
              FactoryEmptyState(
                icon: Symbols.credit_card_rounded,
                title: l10n.paymentCardsEmpty,
                message: l10n.paymentCardsEmptyHint,
                compact: true,
              )
            else
              for (final card in info.cards) ...[
                _CardTile(card: card, onRemove: () => _confirmRemove(context, ref, card)),
                const SizedBox(height: FactorySpacing.space2),
              ],
            if (info.cards.isNotEmpty && !info.canPayWithSavedCard) ...[
              const SizedBox(height: FactorySpacing.space2),
              Text(
                l10n.paymentCardsPageOnlyNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setSave(BuildContext context, WidgetRef ref, bool value) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(paymentsApiProvider).setSaveOnNextPayment(value);
      ref.invalidate(savedCardsProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paymentCardsLoadFailed)));
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, SavedCard card) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.paymentCardsRemoveTitle),
        content: Text(l10n.paymentCardsRemoveBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.paymentCardsKeep)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.paymentCardsRemove)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(paymentsApiProvider).removeSavedCard(card.id);
      ref.invalidate(savedCardsProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paymentCardsRemoveFailed)));
    }
  }
}

/// "VISA •••• 4242" — what a saved card is called everywhere in the app.
String savedCardLabel(AppLocalizations l10n, SavedCard card) =>
    l10n.paymentCardLabel(card.brand ?? l10n.paymentCardGenericBrand, card.last4 ?? '••••');

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onRemove});

  final SavedCard card;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return FactoryCard(
      child: Row(
        children: [
          Icon(Symbols.credit_card_rounded, color: colors.textSecondary),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Text(
              savedCardLabel(l10n, card),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onRemove, child: Text(l10n.paymentCardsRemove)),
        ],
      ),
    );
  }
}
