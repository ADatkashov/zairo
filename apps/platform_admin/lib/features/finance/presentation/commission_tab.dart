import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/commission_models.dart';
import '../data/finance_api.dart';

/// The marketplace commission ZAIRO takes from each booking payment: one
/// platform-wide default (0% until changed) and an optional own rate per
/// category. A change applies to payments made afterwards — existing payments
/// keep the rate they were made with.
class CommissionTab extends ConsumerWidget {
  const CommissionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final canEdit = ref.watch(permissionsProvider).canEditCommission;
    final language = Localizations.localeOf(context).languageCode;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(commissionProvider);

    return AsyncView<CommissionSettings>(
      value: async,
      onRetry: () => ref.invalidate(commissionProvider),
      builder: (settings) => RefreshIndicator(
        onRefresh: () => ref.refresh(commissionProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            FactoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.commissionDefaultTitle, style: textTheme.titleSmall?.copyWith(color: colors.text)),
                  const SizedBox(height: FactorySpacing.space2),
                  Text(
                    formatPercent(settings.defaultPercent),
                    style: FactoryTypography.mono(size: 28, weight: FontWeight.w600, color: colors.text),
                  ),
                  const SizedBox(height: FactorySpacing.space1),
                  Text(
                    l10n.commissionDefaultHelp,
                    style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                  if (canEdit) ...[
                    const SizedBox(height: FactorySpacing.space3),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FactoryButton(
                        label: l10n.commissionChange,
                        onPressed: () => _edit(
                          context,
                          ref,
                          title: l10n.commissionDefaultTitle,
                          save: (percent) => ref.read(financeApiProvider).setDefaultCommission(percent),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: FactorySpacing.space4),
            Text(l10n.commissionCategoriesTitle, style: textTheme.titleSmall?.copyWith(color: colors.text)),
            const SizedBox(height: FactorySpacing.space2),
            for (final category in settings.categories)
              Padding(
                padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                child: FactoryCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.displayName(language),
                              style: textTheme.titleSmall?.copyWith(color: colors.text),
                            ),
                          ),
                          Text(
                            formatPercent(category.effectivePercent),
                            style: FactoryTypography.mono(size: 18, weight: FontWeight.w600, color: colors.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: FactorySpacing.space1),
                      Text(
                        category.hasOverride ? l10n.commissionOwnRate : l10n.commissionFollowsDefault,
                        style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                      ),
                      if (canEdit) ...[
                        const SizedBox(height: FactorySpacing.space3),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: FactorySpacing.space2,
                          runSpacing: FactorySpacing.space2,
                          children: [
                            if (category.hasOverride)
                              FactoryButton(
                                label: l10n.commissionUseDefault,
                                variant: FactoryButtonVariant.secondary,
                                onPressed: () => _reset(context, ref, category),
                              ),
                            FactoryButton(
                              label: l10n.commissionChange,
                              onPressed: () => _edit(
                                context,
                                ref,
                                title: category.displayName(language),
                                save: (percent) =>
                                    ref.read(financeApiProvider).setCategoryCommission(category.categoryId, percent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required Future<CommissionSettings> Function(num percent) save,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final input = await promptText(
      context,
      title: title,
      message: l10n.commissionEditMessage,
      fieldLabel: l10n.commissionField,
      confirmLabel: l10n.commissionSave,
      required: true,
    );
    if (input == null || !context.mounted) return;
    final percent = parsePercentInput(input);
    if (percent == null) {
      showSnack(context, l10n.commissionInvalid);
      return;
    }
    await _run(context, ref, () => save(percent), l10n.commissionSaved);
  }

  Future<void> _reset(BuildContext context, WidgetRef ref, CategoryCommission category) {
    final l10n = AppLocalizations.of(context)!;
    return _run(
      context,
      ref,
      () => ref.read(financeApiProvider).clearCategoryCommission(category.categoryId),
      l10n.commissionReset,
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<CommissionSettings> Function() action,
    String done,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await action();
      ref.invalidate(commissionProvider);
      if (context.mounted) showSnack(context, done);
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(l10n, error));
    }
  }
}
