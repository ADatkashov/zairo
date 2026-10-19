import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/booking_exception.dart';
import '../../data/models/availability_slot.dart';
import '../../data/models/booking.dart';
import '../../data/models/reschedule_option.dart';
import '../providers/booking_providers.dart';
import 'day_slot_picker.dart';

/// "Reschedule": the free times of the same business and person in the booking's own day / time picker. One tap on a time moves the booking
/// (a move is easy to undo by moving again, so there is no extra confirmation). Pops with the moved [Booking], or null
/// when the sheet was dismissed.
Future<Booking?> showRescheduleSheet(BuildContext context, {required Booking booking}) {
  return showFactoryBottomSheet<Booking>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RescheduleSheet(booking: booking),
  );
}

class _RescheduleSheet extends ConsumerStatefulWidget {
  const _RescheduleSheet({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<_RescheduleSheet> {
  bool _moving = false;
  String? _error;

  Future<void> _pick(RescheduleOption option) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _moving = true;
      _error = null;
    });
    try {
      final moved = await ref.read(bookingApiProvider).reschedule(widget.booking.id, option.slotId);
      if (!mounted) return;
      Navigator.of(context).pop(moved);
    } on BookingException catch (e) {
      // Most often "that time was just taken": show it and refresh the list so the taken time disappears.
      ref.invalidate(rescheduleOptionsProvider(widget.booking.id));
      if (!mounted) return;
      setState(() {
        _error = e.localizedMessage(l10n);
        _moving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = l10n.errorBookingGeneric;
        _moving = false;
      });
    }
  }

  ValueChanged<String> _pickById(List<RescheduleOption> items) =>
      (slotId) => _pick(items.firstWhere((o) => o.slotId == slotId));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final options = ref.watch(rescheduleOptionsProvider(widget.booking.id));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.bookingRescheduleTitle, style: textTheme.titleMedium),
          const SizedBox(height: FactorySpacing.space1),
          Text(l10n.bookingRescheduleHint, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
          if (_error != null) ...[
            const SizedBox(height: FactorySpacing.space2),
            Text(_error!, style: textTheme.bodySmall?.copyWith(color: colors.error)),
          ],
          const SizedBox(height: FactorySpacing.space3),
          Flexible(
            child: options.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(FactorySpacing.space4),
                child: FactoryLoadingState(),
              ),
              error: (error, stackTrace) => FactoryErrorState(
                message: l10n.errorBookingGeneric,
                onRetry: () => ref.invalidate(rescheduleOptionsProvider(widget.booking.id)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space4),
                    child: Text(l10n.bookingRescheduleEmpty, style: textTheme.bodyMedium),
                  );
                }
                // The same day / time picker as a new booking; a tap on a time moves the booking at once.
                final slots = [
                  for (final option in items)
                    AvailabilitySlot(
                      id: option.slotId,
                      providerId: widget.booking.providerId ?? '',
                      startsAt: option.startsAt,
                      endsAt: option.endsAt,
                      status: 'OPEN',
                    ),
                ];
                return SingleChildScrollView(
                  child: IgnorePointer(
                    ignoring: _moving,
                    child: DaySlotPicker(slots: slots, selectedSlotId: null, onSelected: _pickById(items)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
