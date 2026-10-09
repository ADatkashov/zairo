import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../data/models/change_request.dart';
import '../providers/workforce_providers.dart';

/// "Your master can't make it": the customer picks a colleague at the same time, another time with the
/// same person, or a refunded cancellation.
class ChangeRequestsScreen extends ConsumerWidget {
  const ChangeRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final requests = ref.watch(changeRequestsProvider);
    return Scaffold(
      backgroundColor: context.factoryColors.bg,
      appBar: FactoryAppBar(title: l10n.changeRequestsTitle),
      body: requests.when(
        data: (items) => items.isEmpty
            ? Center(child: FactoryEmptyState(icon: Icons.event_available_outlined, message: '', title: l10n.changeRequestsEmpty))
            : ListView(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                children: [
                  for (final r in items) ...[
                    _RequestCard(request: r),
                    const SizedBox(height: FactorySpacing.space3),
                  ],
                ],
              ),
        loading: () => const FactoryLoadingState(),
        error: (error, _) => Center(
          child: FactoryErrorState(
            message: l10n.errorProfileGeneric,
            onRetry: () => ref.invalidate(changeRequestsProvider),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request});

  final ChangeRequest request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(changeRequestsProvider);
      ref.invalidate(myBookingsProvider);
    } catch (_) {
      if (!mounted) return;
      // The offer may have gone stale (someone took the time): refresh the options too.
      ref.invalidate(changeRequestsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.changeRequestsFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.changeRequestsCancelConfirmTitle,
      message: l10n.changeRequestsCancelConfirmMessage,
      actions: [
        Builder(
          builder: (c) => FactoryButton(
            label: l10n.changeRequestsKeep,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(c).pop(false),
          ),
        ),
        Builder(
          builder: (c) => FactoryButton(
            label: l10n.changeRequestsCancel,
            variant: FactoryButtonVariant.danger,
            onPressed: () => Navigator.of(c).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    await _run(() => ref.read(changeRequestApiProvider).cancel(widget.request.bookingId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final r = widget.request;
    final api = ref.read(changeRequestApiProvider);

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.providerName ?? '', style: textTheme.titleSmall),
          if (r.serviceTitle != null) Text(r.serviceTitle!, style: textTheme.bodyLarge),
          Text(
            '${formatMonthDayTime(l10n, r.startsAt.toLocal())} – ${formatHourMinute(r.endsAt.toLocal())}',
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: FactorySpacing.space2),
          Text(l10n.changeRequestsCantMakeIt(r.workerName ?? '—'), style: textTheme.bodyMedium?.copyWith(color: colors.warning)),
          const SizedBox(height: FactorySpacing.space3),
          if (r.replacements.isNotEmpty) ...[
            Text(l10n.changeRequestsReplaceHeading, style: textTheme.labelLarge),
            Wrap(
              spacing: FactorySpacing.space2,
              children: [
                for (final option in r.replacements)
                  FactoryButton(
                    label: option.name,
                    variant: FactoryButtonVariant.secondary,
                    dense: true,
                    onPressed: _busy ? null : () => _run(() => api.replace(r.bookingId, option.workerId)),
                  ),
              ],
            ),
            const SizedBox(height: FactorySpacing.space2),
          ],
          if (r.otherTimes.isNotEmpty) ...[
            Text(l10n.changeRequestsMoveHeading(r.workerName ?? '—'), style: textTheme.labelLarge),
            Wrap(
              spacing: FactorySpacing.space2,
              children: [
                for (final t in r.otherTimes.take(8))
                  FactoryButton(
                    label: formatMonthDayTime(l10n, t.startsAt.toLocal()),
                    variant: FactoryButtonVariant.secondary,
                    dense: true,
                    onPressed: _busy ? null : () => _run(() => api.move(r.bookingId, t.slotId)),
                  ),
              ],
            ),
            const SizedBox(height: FactorySpacing.space2),
          ],
          FactoryButton(
            label: l10n.changeRequestsCancel,
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
