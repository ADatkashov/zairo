import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/labels.dart';
import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../data/finance_api.dart';
import '../data/finance_models.dart';

/// Money that has to go back to customers. "Failed" lists payments whose
/// refund gave up — someone is still owed that money; the other views are the
/// refund queue's own states. Any role can check a payment against the payment
/// provider; that only reads, it never changes anything.
class RefundsTab extends ConsumerStatefulWidget {
  const RefundsTab({super.key});

  @override
  ConsumerState<RefundsTab> createState() => _RefundsTabState();
}

class _RefundsTabState extends ConsumerState<RefundsTab> {
  /// 'FAILED_PAYMENTS' or a refund-queue status.
  String _view = 'FAILED_PAYMENTS';

  static const _queueStatuses = ['RETRY', 'PENDING', 'PROCESSING', 'FAILED', 'SUCCEEDED'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.refundsHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.factoryColors.textSecondary),
              ),
              const SizedBox(height: FactorySpacing.space3),
              Wrap(
                spacing: FactorySpacing.space2,
                runSpacing: FactorySpacing.space2,
                children: [
                  FactoryChip(
                    label: l10n.refundsFailedPayments,
                    selected: _view == 'FAILED_PAYMENTS',
                    onTap: () => setState(() => _view = 'FAILED_PAYMENTS'),
                  ),
                  for (final status in _queueStatuses)
                    FactoryChip(
                      label: refundRequestStatusLabel(l10n, status),
                      selected: _view == status,
                      onTap: () => setState(() => _view = status),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _view == 'FAILED_PAYMENTS' ? const _FailedPayments() : _Queue(status: _view)),
      ],
    );
  }
}

class _FailedPayments extends ConsumerWidget {
  const _FailedPayments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(failedRefundsProvider);
    Future<void> refresh() => ref.refresh(failedRefundsProvider.future);
    return AsyncView<List<FailedRefundPayment>>(
      value: async,
      onRetry: () => ref.invalidate(failedRefundsProvider),
      builder: (payments) {
        if (payments.isEmpty) {
          return EmptyView(
            icon: Icons.check_circle_outline_rounded,
            title: l10n.refundsNoneFailedTitle,
            message: l10n.refundsNoneFailedMessage,
            onRefresh: refresh,
          );
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
              for (final payment in payments)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: _RefundCard(
                    amount: payment.amount,
                    currency: payment.currency,
                    badge: ToneBadge(label: paymentStatusLabel(l10n, payment.status), tone: Tone.bad),
                    bookingId: payment.bookingId,
                    paymentId: payment.id,
                    lines: [
                      l10n.refundAttempts(payment.refundAttempts),
                      if (payment.refundFailureReason != null && payment.refundFailureReason!.isNotEmpty)
                        payment.refundFailureReason!,
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Queue extends ConsumerWidget {
  const _Queue({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final async = ref.watch(refundRequestsProvider(status));
    Future<void> refresh() => ref.refresh(refundRequestsProvider(status).future);
    return AsyncView<List<RefundRequest>>(
      value: async,
      onRetry: () => ref.invalidate(refundRequestsProvider(status)),
      builder: (requests) {
        if (requests.isEmpty) {
          return EmptyView(icon: Icons.inbox_outlined, title: l10n.refundsQueueEmpty, onRefresh: refresh);
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
              for (final request in requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: _RefundCard(
                    amount: request.amount,
                    currency: request.currency,
                    badge: ToneBadge(
                      label: refundRequestStatusLabel(l10n, request.status),
                      tone: refundRequestStatusTone(request.status),
                    ),
                    bookingId: request.bookingId,
                    paymentId: request.paymentId,
                    lines: [
                      l10n.refundAttempts(request.attempts),
                      if (request.nextAttemptAt != null)
                        l10n.refundNextAttempt(formatDateTime(locale, request.nextAttemptAt!)),
                      if (request.lastError != null && request.lastError!.isNotEmpty) request.lastError!,
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RefundCard extends ConsumerWidget {
  const _RefundCard({
    required this.amount,
    required this.currency,
    required this.badge,
    required this.bookingId,
    required this.paymentId,
    required this.lines,
  });

  final num amount;
  final String currency;
  final Widget badge;
  final String bookingId;
  final String paymentId;
  final List<String> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatMoney(locale, amount, currency),
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              badge,
            ],
          ),
          const SizedBox(height: FactorySpacing.space1),
          SelectableText(
            l10n.refundBooking(bookingId),
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
          for (final line in lines) Text(line, style: textTheme.bodySmall),
          const SizedBox(height: FactorySpacing.space3),
          Align(
            alignment: Alignment.centerRight,
            child: FactoryButton(
              label: l10n.reconcileButton,
              icon: Icons.sync_alt_rounded,
              variant: FactoryButtonVariant.secondary,
              onPressed: () => _reconcile(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reconcile(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await ref.read(financeApiProvider).reconcile(paymentId);
      if (!context.mounted) return;
      await showFactoryDialog<void>(
        context: context,
        title: result.isMatch ? l10n.reconcileMatchTitle : l10n.reconcileDiscrepancyTitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.isMatch ? l10n.reconcileMatchMessage : l10n.reconcileDiscrepancyMessage),
            const SizedBox(height: FactorySpacing.space3),
            Text(l10n.reconcileLocal(paymentStatusLabel(l10n, result.localStatus))),
            Text(
              l10n.reconcileProvider(
                result.providerStatus == null ? l10n.reconcileNoProviderStatus : humanizeCode(result.providerStatus!),
              ),
            ),
            if (result.providerReference != null) SelectableText(l10n.reconcileReference(result.providerReference!)),
          ],
        ),
        actions: [
          Builder(
            builder: (dialogContext) =>
                FactoryButton(label: l10n.close, onPressed: () => Navigator.of(dialogContext).pop()),
          ),
        ],
      );
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(l10n, error));
    }
  }
}
