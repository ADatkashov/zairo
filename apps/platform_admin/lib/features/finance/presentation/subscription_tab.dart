import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/commission_models.dart';
import '../data/finance_api.dart';

/// What the PRO plan costs owners per month: set here by the platform admin, not in code. Everyone may read it;
/// only PLATFORM_ADMIN may change it. A new price applies to charges made afterwards.
class SubscriptionTab extends ConsumerWidget {
  const SubscriptionTab({super.key});

  /// The platform charges in tenge.
  static const currency = 'KZT';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final canEdit = ref.watch(permissionsProvider).canEditCommission;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final async = ref.watch(subscriptionPriceProvider);

    return AsyncView<SubscriptionPrice>(
      value: async,
      onRetry: () => ref.invalidate(subscriptionPriceProvider),
      builder: (price) => RefreshIndicator(
        onRefresh: () => ref.refresh(subscriptionPriceProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            FactoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.subscriptionPriceTitle, style: textTheme.titleSmall?.copyWith(color: colors.text)),
                  const SizedBox(height: FactorySpacing.space2),
                  Text(
                    '${formatMoney(locale, price.monthlyPrice, price.currency)} ${l10n.subscriptionPerMonth}',
                    key: const Key('subscriptionPrice'),
                    style: FactoryTypography.mono(size: 24, weight: FontWeight.w600, color: colors.text),
                  ),
                  const SizedBox(height: FactorySpacing.space1),
                  Text(
                    l10n.subscriptionPriceHelp,
                    style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                  if (price.currency != currency) ...[
                    const SizedBox(height: FactorySpacing.space2),
                    Text(
                      l10n.subscriptionNotTenge(price.currency),
                      style: textTheme.bodySmall?.copyWith(color: colors.error),
                    ),
                  ],
                  if (canEdit) ...[
                    const SizedBox(height: FactorySpacing.space3),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FactoryButton(
                        label: l10n.commissionChange,
                        onPressed: () => _edit(context, ref),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final input = await promptText(
      context,
      title: l10n.subscriptionPriceTitle,
      message: l10n.subscriptionPriceEditMessage,
      fieldLabel: l10n.subscriptionPriceField,
      confirmLabel: l10n.commissionSave,
      required: true,
    );
    if (input == null || !context.mounted) return;
    final amount = parsePriceInput(input);
    if (amount == null) {
      showSnack(context, l10n.subscriptionPriceInvalid);
      return;
    }
    try {
      await ref.read(financeApiProvider).setSubscriptionPrice(amount, currency);
      ref.invalidate(subscriptionPriceProvider);
      if (context.mounted) showSnack(context, l10n.subscriptionPriceSaved);
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(l10n, error));
    }
  }
}
