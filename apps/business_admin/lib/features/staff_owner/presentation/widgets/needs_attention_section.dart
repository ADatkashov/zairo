import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/needs_attention.dart';
import '../providers/staff_owner_providers.dart';

/// "Needs your decision": appointments where a staff member said they can't attend. Shows nothing at all
/// when there is nothing to decide, so a quiet business has no extra section.
class NeedsAttentionSection extends ConsumerWidget {
  const NeedsAttentionSection({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(needsAttentionProvider(providerId)).value ?? const <NeedsAttentionItem>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.needsAttentionTitle),
        const SizedBox(height: FactorySpacing.space2),
        for (final item in items) ...[
          _NeedsAttentionCard(providerId: providerId, item: item),
          const SizedBox(height: FactorySpacing.space3),
        ],
        const SizedBox(height: FactorySpacing.space3),
      ],
    );
  }
}

class _NeedsAttentionCard extends ConsumerStatefulWidget {
  const _NeedsAttentionCard({required this.providerId, required this.item});

  final String providerId;
  final NeedsAttentionItem item;

  @override
  ConsumerState<_NeedsAttentionCard> createState() => _NeedsAttentionCardState();
}

class _NeedsAttentionCardState extends ConsumerState<_NeedsAttentionCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.needsAttentionCancelConfirmTitle,
      message: l10n.needsAttentionCancelConfirmMessage,
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.needsAttentionKeepButton,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.needsAttentionCancelButton,
            variant: FactoryButtonVariant.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(staffOwnerApiProvider).cancelAppointment(widget.providerId, widget.item.bookingId);
      ref.invalidate(needsAttentionProvider(widget.providerId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.needsAttentionCancelFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final item = widget.item;

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatMonthDayTime(l10n, item.startsAt.toLocal())} – ${formatHourMinute(item.endsAt.toLocal())}',
                  style: textTheme.titleSmall,
                ),
              ),
              FactoryBadge(label: l10n.needsAttentionBadge, variant: FactoryBadgeVariant.limited),
            ],
          ),
          const SizedBox(height: FactorySpacing.space2),
          if (item.serviceTitle != null) Text(item.serviceTitle!, style: textTheme.bodyLarge),
          Text(
            [
              item.customerName ?? l10n.needsAttentionCustomer,
              if (item.customerPhone != null && item.customerPhone!.isNotEmpty) item.customerPhone!,
            ].join(' · '),
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: FactorySpacing.space1),
          Text(
            l10n.needsAttentionWorkerCannotAttend(item.workerName ?? '—'),
            style: textTheme.bodyMedium?.copyWith(color: colors.warning),
          ),
          if (item.workerNote != null && item.workerNote!.isNotEmpty)
            Text('«${item.workerNote}»', style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
          const SizedBox(height: FactorySpacing.space2),
          FactoryButton(
            label: l10n.needsAttentionCancelButton,
            variant: FactoryButtonVariant.textDanger,
            dense: true,
            isLoading: _busy,
            onPressed: _busy ? null : _cancel,
          ),
        ],
      ),
    );
  }
}
