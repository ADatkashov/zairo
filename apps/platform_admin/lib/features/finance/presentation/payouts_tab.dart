import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/labels.dart';
import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../../businesses/data/business_api.dart';
import '../data/finance_api.dart';
import '../data/finance_models.dart';

/// What businesses are owed, per completed booking (ADR-0007). A payout only
/// becomes PAID when a person confirms the money actually reached the business
/// — the transfer itself happens in the bank, outside this system — so the
/// actions here record that, they don't move money.
class PayoutsTab extends ConsumerStatefulWidget {
  const PayoutsTab({super.key});

  @override
  ConsumerState<PayoutsTab> createState() => _PayoutsTabState();
}

class _PayoutsTabState extends ConsumerState<PayoutsTab> {
  /// null = every payout.
  String? _status = 'PAYABLE';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final canSettle = ref.watch(permissionsProvider).canSettlePayouts;
    final async = ref.watch(payoutsProvider(_status));
    final names = {for (final b in ref.watch(businessesProvider).value ?? const []) b.id: b.name};
    Future<void> refresh() => ref.refresh(payoutsProvider(_status).future);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FactorySpacing.space4,
            FactorySpacing.space4,
            FactorySpacing.space4,
            FactorySpacing.space2,
          ),
          child: Wrap(
            spacing: FactorySpacing.space2,
            runSpacing: FactorySpacing.space2,
            children: [
              for (final status in const ['PAYABLE', 'PROCESSING', 'FAILED', 'PAID'])
                FactoryChip(
                  label: payoutStatusLabel(l10n, status),
                  selected: _status == status,
                  onTap: () => setState(() => _status = status),
                ),
              FactoryChip(
                label: l10n.filterAll,
                selected: _status == null,
                onTap: () => setState(() => _status = null),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<Payout>>(
            value: async,
            onRetry: () => ref.invalidate(payoutsProvider(_status)),
            builder: (payouts) {
              if (payouts.isEmpty) {
                return EmptyView(
                  icon: Icons.payments_outlined,
                  title: l10n.payoutsEmptyTitle,
                  message: l10n.payoutsEmptyMessage,
                  onRefresh: refresh,
                );
              }
              final sorted = [...payouts]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              // One total per currency — never a sum across currencies.
              final totals = <String, num>{};
              for (final p in sorted) {
                totals[p.currency] = (totals[p.currency] ?? 0) + p.amount;
              }
              return RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    FactorySpacing.space4,
                    FactorySpacing.space2,
                    FactorySpacing.space4,
                    FactorySpacing.space6,
                  ),
                  children: [
                    _PayoutsSummary(
                      totals: [for (final e in totals.entries) formatMoney(locale, e.value, e.key)],
                      caption: l10n.payoutsSummary(
                        sorted.length,
                        totals.entries.map((e) => formatMoney(locale, e.value, e.key)).join(' · '),
                      ),
                    ),
                    const SizedBox(height: FactorySpacing.space3),
                    for (final payout in sorted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                        child: _PayoutCard(
                          payout: payout,
                          businessName: names[payout.providerId],
                          canSettle: canSettle,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The money at a glance: one big figure per currency (never summed across
/// currencies), with the plain-language summary underneath.
class _PayoutsSummary extends StatelessWidget {
  const _PayoutsSummary({required this.totals, required this.caption});

  final List<String> totals;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return FactoryCard(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: FactorySpacing.space5,
            runSpacing: FactorySpacing.space1,
            children: [
              for (final total in totals)
                Text(total, style: FactoryTypography.mono(size: 28, weight: FontWeight.w600, color: colors.text)),
            ],
          ),
          const SizedBox(height: FactorySpacing.space1),
          Text(caption, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _PayoutCard extends ConsumerWidget {
  const _PayoutCard({required this.payout, required this.businessName, required this.canSettle});

  final Payout payout;
  final String? businessName;
  final bool canSettle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    final actions = <Widget>[
      if (canSettle && (payout.status == 'PAYABLE' || payout.status == 'FAILED'))
        FactoryButton(
          label: l10n.payoutStartProcessing,
          variant: FactoryButtonVariant.secondary,
          onPressed: () => _markProcessing(context, ref),
        ),
      if (canSettle && payout.status != 'PAID')
        FactoryButton(label: l10n.payoutMarkPaid, onPressed: () => _markPaid(context, ref)),
      if (canSettle && (payout.status == 'PAYABLE' || payout.status == 'PROCESSING'))
        FactoryButton(
          label: l10n.payoutMarkFailed,
          variant: FactoryButtonVariant.textDanger,
          onPressed: () => _markFailed(context, ref),
        ),
    ];

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  businessName ?? l10n.payoutUnknownBusiness,
                  style: textTheme.titleSmall?.copyWith(color: colors.text),
                ),
              ),
              ToneBadge(label: payoutStatusLabel(l10n, payout.status), tone: payoutStatusTone(payout.status)),
            ],
          ),
          const SizedBox(height: FactorySpacing.space2),
          Text(
            formatMoney(locale, payout.amount, payout.currency),
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: FactorySpacing.space1),
          Text(
            [
              l10n.payoutCreatedOn(formatDate(locale, payout.createdAt)),
              if (payout.settledAt != null) l10n.payoutPaidOn(formatDate(locale, payout.settledAt!)),
            ].join(' · '),
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
          if (payout.providerReference != null && payout.providerReference!.isNotEmpty)
            Text(l10n.payoutReference(payout.providerReference!), style: textTheme.bodySmall),
          if (payout.status == 'FAILED' && payout.failureReason != null && payout.failureReason!.isNotEmpty)
            Text(
              l10n.payoutFailureReason(payout.failureReason!),
              style: textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: FactorySpacing.space3),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: FactorySpacing.space2,
              runSpacing: FactorySpacing.space2,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<Object?> Function() action,
    String Function(AppLocalizations) done,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await action();
      ref.invalidate(payoutsProvider);
      if (context.mounted) showSnack(context, done(l10n));
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(l10n, error));
    }
  }

  Future<void> _markProcessing(BuildContext context, WidgetRef ref) => _run(
    context,
    ref,
    () => ref.read(financeApiProvider).markProcessing(payout.id),
    (l10n) => l10n.payoutNowProcessing,
  );

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final reference = await promptText(
      context,
      title: l10n.payoutMarkPaidTitle,
      message: l10n.payoutMarkPaidMessage,
      fieldLabel: l10n.payoutReferenceField,
      confirmLabel: l10n.payoutMarkPaid,
    );
    if (reference == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(financeApiProvider).markPaid(payout.id, reference: reference.isEmpty ? null : reference),
      (l10n) => l10n.payoutNowPaid,
    );
  }

  Future<void> _markFailed(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final reason = await promptText(
      context,
      title: l10n.payoutMarkFailedTitle,
      message: l10n.payoutMarkFailedMessage,
      fieldLabel: l10n.payoutFailureField,
      confirmLabel: l10n.payoutMarkFailed,
      destructive: true,
    );
    if (reason == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(financeApiProvider).markFailed(payout.id, reason: reason.isEmpty ? null : reason),
      (l10n) => l10n.payoutNowFailed,
    );
  }
}
