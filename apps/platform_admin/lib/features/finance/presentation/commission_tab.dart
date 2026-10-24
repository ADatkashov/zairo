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
            // One card, one line per category: the percentage is the thing to edit, so it is the tap target
            // (twenty big "Change" buttons made this a very long page).
            FactoryCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < settings.categories.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: colors.border),
                    _CategoryRow(
                      category: settings.categories[i],
                      language: language,
                      canEdit: canEdit,
                      onEdit: () => _edit(
                        context,
                        ref,
                        title: settings.categories[i].displayName(language),
                        save: (percent) =>
                            ref.read(financeApiProvider).setCategoryCommission(settings.categories[i].categoryId, percent),
                      ),
                      onReset: () => _reset(context, ref, settings.categories[i]),
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.language,
    required this.canEdit,
    required this.onEdit,
    required this.onReset,
  });

  final CategoryCommission category;
  final String language;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: canEdit ? onEdit : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4, vertical: FactorySpacing.space2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.displayName(language), style: textTheme.titleSmall?.copyWith(color: colors.text)),
                  Text(
                    category.hasOverride ? l10n.commissionOwnRate : l10n.commissionFollowsDefault,
                    style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ),
            if (canEdit && category.hasOverride)
              TextButton(onPressed: onReset, child: Text(l10n.commissionUseDefault)),
            const SizedBox(width: FactorySpacing.space2),
            Text(
              formatPercent(category.effectivePercent),
              style: FactoryTypography.mono(size: 18, weight: FontWeight.w600, color: colors.text),
            ),
            if (canEdit) ...[
              const SizedBox(width: FactorySpacing.space3),
              IconButton(
                tooltip: l10n.commissionChange,
                icon: const Icon(Icons.edit_outlined, size: 18),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(minimumSize: const Size(36, 36), fixedSize: const Size(36, 36)),
                onPressed: onEdit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
