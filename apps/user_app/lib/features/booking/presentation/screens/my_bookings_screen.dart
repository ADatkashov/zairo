import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logged_out_gate.dart';
import '../../../messaging/data/messaging_exception.dart';
import '../../../messaging/data/models/chat_message.dart';
import '../../../messaging/data/models/conversation.dart';
import '../../../messaging/presentation/providers/messaging_providers.dart';
import '../../../messaging/presentation/screens/chat_thread_screen.dart';
import '../../../payments/presentation/providers/payments_providers.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../data/models/book_again_suggestion.dart';
import '../../../payments/presentation/widgets/payment_status_chip.dart';
import '../../../reviews/presentation/widgets/review_section.dart';
import '../../../workforce/presentation/widgets/change_requests_banner.dart';
import '../../../workers/presentation/providers/workers_providers.dart';
import '../../data/booking_exception.dart';
import '../../data/models/booking.dart';
import '../providers/booking_providers.dart';
import 'booking_payment_screen.dart';
import '../widgets/reschedule_sheet.dart';
import '../widgets/booking_payment_summary.dart';

/// Reached directly from the bottom nav (a peer tab to Home/Search/
/// Favorites/Profile, not only pushed after already being logged in), so
/// it resolves the current user itself instead of requiring a caller to
/// pass one — see LoggedOutGate for the logged-out path.
class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(
        title: l10n.myBookingsTitle,
        actions: [
          if (authState.value != null)
            const Padding(
              padding: EdgeInsets.only(right: FactorySpacing.space3),
              child: NotificationBellButton(),
            ),
        ],
      ),
      body: authState.when(
        data: (user) => user == null
            ? LoggedOutGate(
                icon: Symbols.calendar_month_rounded,
                message: l10n.bookingsLoggedOutPrompt,
              )
            : Column(
                children: [
                  const ChangeRequestsBanner(),
                  Expanded(child: _BookingsList(userId: user.id)),
                ],
              ),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric,
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

/// The statuses of a booking that is still ahead of the customer: what the
/// "Upcoming" tab lists, and what the profile counts under the same word, so
/// the number on one screen is the number of rows on the other.
const upcomingBookingStatuses = {'CONFIRMED', 'PENDING_PAYMENT'};

enum _BookingsTab { upcoming, completed, cancelled }

extension on _BookingsTab {
  /// The statuses each tab shows. Upcoming also holds a booking that is
  /// still awaiting payment, so the customer can finish paying for it (or
  /// cancel it) instead of it silently disappearing from the list.
  Set<String> get statuses => switch (this) {
    _BookingsTab.upcoming => upcomingBookingStatuses,
    _BookingsTab.completed => const {'COMPLETED'},
    _BookingsTab.cancelled => const {'CANCELLED'},
  };
}

class _BookingsList extends ConsumerStatefulWidget {
  final String userId;

  const _BookingsList({required this.userId});

  @override
  ConsumerState<_BookingsList> createState() => _BookingsListState();
}

class _BookingsListState extends ConsumerState<_BookingsList> {
  _BookingsTab _tab = _BookingsTab.upcoming;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bookingsAsync = ref.watch(myBookingsProvider(widget.userId));

    return bookingsAsync.when(
      data: (bookings) {
        Future<void> refresh() =>
            ref.refresh(myBookingsProvider(widget.userId).future);

        if (bookings.isEmpty) {
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: FactoryEmptyState(
                      icon: Symbols.calendar_month_rounded,
                      title: l10n.bookingsEmptyTitle,
                      message: l10n.bookingsEmptyMessage,
                      actionLabel: l10n.bookingsFindServiceButton,
                      onAction: () => context.push(AppRoutes.search()),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final filtered =
            bookings.where((b) => _tab.statuses.contains(b.status)).toList()
              ..sort((a, b) {
                // The next visit first on "Upcoming"; the most recent first on the
                // other tabs. A booking without a known start time sorts by when
                // it was made instead.
                final byTime = _visitOrKey(a).compareTo(_visitOrKey(b));
                return _tab == _BookingsTab.upcoming ? byTime : -byTime;
              });
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FactorySpacing.space4,
                FactorySpacing.space4,
                FactorySpacing.space4,
                0,
              ),
              child: _BookingsTabBar(
                selected: _tab,
                onSelect: (tab) => setState(() => _tab = tab),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refresh,
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(
                              FactorySpacing.space6,
                            ),
                            child: FactoryEmptyState(
                              icon: Symbols.calendar_month_rounded,
                              title: switch (_tab) {
                                _BookingsTab.upcoming =>
                                  l10n.bookingsTabEmptyTitleUpcoming,
                                _BookingsTab.completed =>
                                  l10n.bookingsTabEmptyTitleCompleted,
                                _BookingsTab.cancelled =>
                                  l10n.bookingsTabEmptyTitleCancelled,
                              },
                              message: switch (_tab) {
                                _BookingsTab.upcoming =>
                                  l10n.bookingsTabEmptyUpcoming,
                                _BookingsTab.completed =>
                                  l10n.bookingsTabEmptyCompleted,
                                _BookingsTab.cancelled =>
                                  l10n.bookingsTabEmptyCancelled,
                              },
                              actionLabel: _tab == _BookingsTab.upcoming
                                  ? l10n.bookingsFindServiceButton
                                  : null,
                              onAction: () => context.push(AppRoutes.search()),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(FactorySpacing.space4),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: FactorySpacing.space3),
                        itemBuilder: (context, index) => _BookingCard(
                          booking: filtered[index],
                          userId: widget.userId,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
      loading: () => const FactoryLoadingState(),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: FactoryErrorState(
            message: l10n.errorBookingsLoadFailed,
            onRetry: () => ref.invalidate(myBookingsProvider(widget.userId)),
          ),
        ),
      ),
    );
  }
}

/// A pill-style segmented control (Customer App Redesign board,
/// 2026-09-05) — filters the already-fetched bookings list client-side by
/// status rather than issuing a new request per tab.
class _BookingsTabBar extends StatelessWidget {
  const _BookingsTabBar({required this.selected, required this.onSelect});

  final _BookingsTab selected;
  final ValueChanged<_BookingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final tabs = {
      _BookingsTab.upcoming: l10n.bookingsTabUpcoming,
      _BookingsTab.completed: l10n.bookingsTabCompleted,
      _BookingsTab.cancelled: l10n.bookingsTabCancelled,
    };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: FactoryRadius.lgRadius,
      ),
      child: Row(
        children: [
          for (final entry in tabs.entries)
            Expanded(
              child: _BookingsTabButton(
                label: entry.value,
                isSelected: entry.key == selected,
                onTap: () => onSelect(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingsTabButton extends StatelessWidget {
  const _BookingsTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Material(
      color: isSelected ? colors.primary : Colors.transparent,
      borderRadius: FactoryRadius.mdRadius,
      child: InkWell(
        borderRadius: FactoryRadius.mdRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isSelected ? colors.onPrimary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Book again" on a completed booking: opens the business straight in the
/// booking flow with the same service — and the same person, when the visit was
/// with a named one — already picked: one tap from the visit to choosing a time. The business comes from the booking itself; an older
/// backend that does not send it falls back to the Book-Again suggestions Home
/// already shows (matched by service), and without either the button is not
/// offered.
class _BookAgainButton extends ConsumerWidget {
  const _BookAgainButton({required this.booking, required this.userId});

  final Booking booking;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    BookAgainSuggestion? match;
    var providerId = booking.providerId;
    if (providerId == null) {
      final suggestions = ref.watch(bookAgainSuggestionsProvider(userId)).value;
      for (final suggestion in suggestions ?? const <BookAgainSuggestion>[]) {
        if (suggestion.serviceId == booking.serviceId) {
          match = suggestion;
          providerId = suggestion.providerId;
          break;
        }
      }
    }
    final targetProviderId = providerId;
    if (targetProviderId == null) return const SizedBox.shrink();

    return FactoryButton(
      label: AppLocalizations.of(context)!.bookingBookAgainButton,
      variant: FactoryButtonVariant.text,
      onPressed: () async {
        // The same person again, when the visit was with a named one (and still works there); a lookup that
        // fails or finds nobody just books the service without a preferred person.
        final worker = await ref.read(bookingWorkerProvider(booking.id).future);
        if (!context.mounted) return;
        context.push(
          AppRoutes.provider(
            targetProviderId,
            book: true,
            serviceId: booking.serviceId,
            workerId: worker?.id,
            workerKind: worker?.kind,
          ),
          extra: match?.toProviderSearchResult(),
        );
      },
    );
  }
}

/// The time a booking is ordered by: its appointment start when known,
/// otherwise when it was made.
DateTime _visitOrKey(Booking b) => b.startsAt ?? b.createdAt;

/// What was booked, with whom and when — the part of a booking card a
/// customer actually looks for. Each line is shown only if the backend sent it.
class _BookingHeadline extends StatelessWidget {
  final Booking booking;

  const _BookingHeadline({required this.booking});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final start = booking.startsAt?.toLocal();
    final end = booking.endsAt?.toLocal();
    final when = start == null
        ? null
        : '${formatWeekdayMonthDay(l10n, start)} · ${formatHourMinute(start)}'
              '${end == null ? '' : '–${formatHourMinute(end)}'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (booking.serviceTitle != null)
            Text(booking.serviceTitle!, style: textTheme.titleSmall),
          if (booking.providerName != null)
            Text(
              booking.providerName!,
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          if (when != null) ...[
            const SizedBox(height: FactorySpacing.space1),
            Row(
              children: [
                Icon(Symbols.event_rounded, size: 16, color: colors.primary),
                const SizedBox(width: FactorySpacing.space1),
                Flexible(
                  child: Text(
                    when,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingCard extends ConsumerStatefulWidget {
  final Booking booking;
  final String userId;

  const _BookingCard({required this.booking, required this.userId});

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final booking = widget.booking;

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (booking.serviceTitle != null || booking.startsAt != null)
            _BookingHeadline(booking: booking),
          // Full card width: beside a status badge the amounts wrapped into a
          // narrow column and the appointment time broke onto two lines.
          BookingAmounts(booking: booking, compact: true),
          const SizedBox(height: FactorySpacing.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l10n.bookedOnLabel(
                    formatMonthDayTime(l10n, booking.createdAt.toLocal()),
                  ),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.textTertiary),
                ),
              ),
              const SizedBox(width: FactorySpacing.space2),
              Flexible(
                child: FactoryBadge(
                  label: _statusLabel(l10n, booking.status),
                  variant: _statusVariant(booking.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space2),
          PaymentStatusChip(bookingId: booking.id),
          if (booking.status == 'COMPLETED')
            ReviewSection(bookingId: booking.id),
          const SizedBox(height: FactorySpacing.space2),
          // What the person usually wants comes first; the destructive "Cancel"
          // is on its own line at the far edge, so a tap meant for Reschedule
          // or Message cannot land on it.
          Wrap(
            spacing: FactorySpacing.space2,
            children: [
              if (booking.status == 'PENDING_PAYMENT')
                FactoryButton(
                  label: l10n.bookingPayNowButton,
                  onPressed: _payNow,
                ),
              if (booking.status == 'COMPLETED')
                _BookAgainButton(booking: booking, userId: widget.userId),
              if (_canReschedule(booking))
                FactoryButton(
                  label: l10n.bookingRescheduleButton,
                  variant: FactoryButtonVariant.text,
                  onPressed: _reschedule,
                ),
              FactoryButton(
                label: l10n.messageAboutBookingButton,
                variant: FactoryButtonVariant.text,
                onPressed: _openMessageAboutBookingDialog,
              ),
            ],
          ),
          if (booking.status == 'CONFIRMED' ||
              booking.status == 'PENDING_PAYMENT')
            Align(
              alignment: Alignment.centerRight,
              child: FactoryButton(
                label: l10n.cancelBookingButton,
                variant: FactoryButtonVariant.textDanger,
                isLoading: _isCancelling,
                onPressed: _isCancelling ? null : _confirmAndCancel,
              ),
            ),
        ],
      ),
    );
  }

  /// Opens a small compose dialog, sends the message tagged with this
  /// booking, then — per the spec's fallback rule — looks the resulting
  /// conversation up via `myInbox()` (the response only carries a
  /// conversationId, and this screen has no client-side providerId for a
  /// [Booking] to key a thread screen off of directly) and pushes straight
  /// into [ChatThreadScreen]. Falls back to a plain success snackbar if
  /// that lookup can't find a match.
  Future<void> _openMessageAboutBookingDialog() async {
    final message = await showDialog<ChatMessage>(
      context: context,
      builder: (_) => _MessageAboutBookingDialog(bookingId: widget.booking.id),
    );
    if (message == null || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    Conversation? matched;
    try {
      final conversations = await ref.read(messagingApiProvider).myInbox();
      for (final conversation in conversations) {
        if (conversation.id == message.conversationId) {
          matched = conversation;
          break;
        }
      }
    } catch (_) {
      // Falls through to the snackbar fallback below — the message itself
      // already sent successfully.
    }
    if (!mounted) return;
    if (matched != null) {
      context.push(
        AppRoutes.chat(
          matched.providerId,
          providerName:
              matched.providerName ?? l10n.messagingUnknownBusinessName,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.messageAboutBookingSentMessage)),
    );
  }

  /// Resumes payment for a booking that is still awaiting it. The payment
  /// screen pops with `true` once the server confirms the booking.
  Future<void> _payNow() async {
    await context.push<bool>(
      AppRoutes.bookingPayment,
      extra: BookingPaymentArgs(booking: widget.booking),
    );
    if (!mounted) return;
    ref.invalidate(myBookingsProvider(widget.userId));
  }

  /// An active booking whose appointment has not started (a booking without a known time is offered the move too:
  /// the server decides).
  bool _canReschedule(Booking booking) =>
      (booking.status == 'CONFIRMED' || booking.status == 'PENDING_PAYMENT') &&
      (booking.startsAt == null || booking.startsAt!.isAfter(DateTime.now()));

  Future<void> _reschedule() async {
    final l10n = AppLocalizations.of(context)!;
    final moved = await showRescheduleSheet(context, booking: widget.booking);
    if (moved == null || !mounted) return;
    ref.invalidate(myBookingsProvider(widget.userId));
    final when = moved.startsAt;
    if (when == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.bookingRescheduleDone(formatMonthDayTime(l10n, when.toLocal())),
        ),
      ),
    );
  }

  Future<void> _confirmAndCancel() async {
    final l10n = AppLocalizations.of(context)!;
    // An optional, one-tap reason: the business learns why, the customer is never forced to say.
    final reasons = [
      l10n.cancelReasonPlans,
      l10n.cancelReasonOtherTime,
      l10n.cancelReasonMistake,
    ];
    String? reason;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.cancelBookingConfirmTitle,
      message: l10n.cancelBookingConfirmMessage,
      content: StatefulBuilder(
        builder: (context, setDialogState) => Wrap(
          spacing: FactorySpacing.space2,
          runSpacing: FactorySpacing.space2,
          children: [
            for (final option in reasons)
              ChoiceChip(
                label: Text(option),
                selected: reason == option,
                onSelected: (picked) =>
                    setDialogState(() => reason = picked ? option : null),
              ),
          ],
        ),
      ),
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.cancelBookingKeepButton,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.cancelBookingConfirmButton,
            variant: FactoryButtonVariant.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await ref
          .read(bookingApiProvider)
          .cancelBooking(widget.booking.id, reason: reason);
      ref.invalidate(myBookingsProvider(widget.userId));
      ref.invalidate(paymentForBookingProvider(widget.booking.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.bookingCancelledMessage)));
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      setState(() => _isCancelling = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.errorBookingGeneric)));
      setState(() => _isCancelling = false);
    }
  }
}

/// A single multiline field + Send/Cancel, same shape as
/// ReviewSection's `_LeaveReviewDialog` — its own stateful dialog widget
/// rather than a plain `showFactoryDialog` call, since it needs to own an
/// in-flight/error state while the send is pending.
class _MessageAboutBookingDialog extends ConsumerStatefulWidget {
  final String bookingId;

  const _MessageAboutBookingDialog({required this.bookingId});

  @override
  ConsumerState<_MessageAboutBookingDialog> createState() =>
      _MessageAboutBookingDialogState();
}

class _MessageAboutBookingDialogState
    extends ConsumerState<_MessageAboutBookingDialog> {
  final _bodyController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: l10n.messageAboutBookingDialogTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactoryTextField(
            controller: _bodyController,
            enabled: !_isSubmitting,
            label: l10n.chatComposeLabel,
            maxLines: 4,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        FactoryButton(
          label: l10n.messageAboutBookingCancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: l10n.messageAboutBookingSendButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _bodyController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = l10n.messageAboutBookingEmptyError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final message = await ref
          .read(messagingApiProvider)
          .sendAboutBooking(widget.bookingId, text);
      if (!mounted) return;
      Navigator.of(context).pop(message);
    } on MessagingException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.localizedMessage(l10n);
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.errorMessagingGeneric;
        _isSubmitting = false;
      });
    }
  }
}

String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
  'PENDING_PAYMENT' => l10n.bookingStatusPendingPayment,
  'CONFIRMED' => l10n.bookingStatusConfirmed,
  'COMPLETED' => l10n.bookingStatusCompleted,
  'CANCELLED' => l10n.bookingStatusCancelled,
  _ =>
    status.isEmpty
        ? status
        : '${status[0]}${status.substring(1).toLowerCase()}',
};

FactoryBadgeVariant _statusVariant(String status) => switch (status) {
  'PENDING_PAYMENT' => FactoryBadgeVariant.limited,
  'CONFIRMED' => FactoryBadgeVariant.available,
  'COMPLETED' => FactoryBadgeVariant.verified,
  'CANCELLED' => FactoryBadgeVariant.error,
  _ => FactoryBadgeVariant.neutral,
};
