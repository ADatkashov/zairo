import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/data/models/schedule_entry.dart';
import '../../data/models/reschedule_option.dart';
import '../providers/staff_owner_providers.dart';

/// Wraps the agenda row of an active appointment: tapping offers what the owner can do with it — move it to another
/// time (before it starts), or say how it ended (after it started): the visit happened, or the customer did not come.
class AppointmentActions extends ConsumerWidget {
  const AppointmentActions({super.key, required this.item, required this.onChanged, required this.child});

  final AgendaItem item;
  final VoidCallback onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => showFactoryBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ActionsSheet(item: item, onChanged: onChanged),
      ),
      child: child,
    );
  }
}

class _ActionsSheet extends ConsumerStatefulWidget {
  const _ActionsSheet({required this.item, required this.onChanged});

  final AgendaItem item;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ActionsSheet> createState() => _ActionsSheetState();
}

class _ActionsSheetState extends ConsumerState<_ActionsSheet> {
  bool _moving = false;
  bool _busy = false;
  String? _error;

  bool get _started => !widget.item.entry.startsAt.isAfter(DateTime.now());

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
      navigator.pop();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      if (!mounted) return;
      // Most often "that time was just taken": refresh the list so the taken time disappears.
      ref.invalidate(ownerRescheduleOptionsProvider(widget.item.entry.bookingId));
      setState(() {
        _error = l10n.appointmentActionFailed;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final api = ref.read(staffOwnerApiProvider);
    final id = widget.item.entry.bookingId;
    final confirmed = widget.item.entry.status == 'CONFIRMED';

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.item.serviceTitle, style: textTheme.titleMedium),
          if (_error != null) ...[
            const SizedBox(height: FactorySpacing.space2),
            Text(_error!, style: textTheme.bodySmall?.copyWith(color: colors.error)),
          ],
          const SizedBox(height: FactorySpacing.space3),
          if (_moving)
            Flexible(
              child: _MoveOptions(
                bookingId: id,
                enabled: !_busy,
                onPick: (option) => _run(() => api.reschedule(id, option.slotId), done: l10n.appointmentMoved),
              ),
            )
          else ...[
            if (!_started)
              ListTile(
                leading: const Icon(Symbols.event_repeat),
                title: Text(l10n.appointmentActionsMove),
                onTap: _busy ? null : () => setState(() => _moving = true),
              ),
            if (_started && confirmed) ...[
              ListTile(
                leading: const Icon(Symbols.check_circle),
                title: Text(l10n.appointmentActionsComplete),
                onTap: _busy ? null : () => _run(() => api.markCompleted(id)),
              ),
              ListTile(
                leading: Icon(Symbols.person_off, color: colors.error),
                title: Text(l10n.appointmentActionsNoShow),
                onTap: _busy ? null : () => _run(() => api.markNoShow(id)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MoveOptions extends ConsumerWidget {
  const _MoveOptions({required this.bookingId, required this.enabled, required this.onPick});

  final String bookingId;
  final bool enabled;
  final void Function(RescheduleOption option) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final options = ref.watch(ownerRescheduleOptionsProvider(bookingId));

    return options.when(
      loading: () => const Padding(padding: EdgeInsets.all(FactorySpacing.space4), child: FactoryLoadingState()),
      error: (error, stackTrace) => FactoryErrorState(
        message: l10n.appointmentActionFailed,
        onRetry: () => ref.invalidate(ownerRescheduleOptionsProvider(bookingId)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space4),
            child: Text(l10n.appointmentMoveEmpty, style: textTheme.bodyMedium),
          );
        }
        final byDay = <DateTime, List<RescheduleOption>>{};
        for (final option in items) {
          final local = option.startsAt.toLocal();
          byDay.putIfAbsent(DateTime(local.year, local.month, local.day), () => []).add(option);
        }
        return ListView(
          shrinkWrap: true,
          children: [
            Text(l10n.appointmentMoveHint, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: FactorySpacing.space3),
            for (final day in byDay.entries) ...[
              Text(DateFormat.MMMEd(locale).format(day.key), style: textTheme.titleSmall),
              const SizedBox(height: FactorySpacing.space2),
              Wrap(
                spacing: FactorySpacing.space2,
                runSpacing: FactorySpacing.space2,
                children: [
                  for (final option in day.value)
                    FactoryTimeSlot(
                      label: DateFormat.Hm(locale).format(option.startsAt.toLocal()),
                      onTap: enabled ? () => onPick(option) : null,
                    ),
                ],
              ),
              const SizedBox(height: FactorySpacing.space4),
            ],
          ],
        );
      },
    );
  }
}
