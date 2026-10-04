import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

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
import '../../../payments/presentation/widgets/payment_status_chip.dart';
import '../../../reviews/presentation/widgets/review_section.dart';
import '../../data/booking_exception.dart';
import '../../data/models/booking.dart';
import '../providers/booking_providers.dart';
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
      appBar: FactoryAppBar(title: l10n.myBookingsTitle),
      body: authState.when(
        data: (user) => user == null
            ? LoggedOutGate(
                icon: Symbols.calendar_month_rounded,
                message: l10n.bookingsLoggedOutPrompt,
              )
            : _BookingsList(userId: user.id),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric(error.toString()),
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

enum _BookingsTab { upcoming, completed, cancelled }

extension on _BookingsTab {
  /// The single status each tab filters to — this screen only ever shows
  /// CONFIRMED/COMPLETED/CANCELLED bookings (see [Booking.status]), so a
  /// direct 1:1 mapping is enough; no tab needs to match more than one status.
  String get status => switch (this) {
    _BookingsTab.upcoming => 'CONFIRMED',
    _BookingsTab.completed => 'COMPLETED',
    _BookingsTab.cancelled => 'CANCELLED',
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
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final sorted = [...bookings]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final filtered = sorted.where((b) => b.status == _tab.status).toList();
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
                            padding: const EdgeInsets.all(FactorySpacing.space4),
                            child: Text(
                              l10n.bookingsEmptyMessage,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: context.factoryColors.textTertiary,
                                  ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: BookingAmounts(booking: booking, compact: true),
              ),
              const SizedBox(width: FactorySpacing.space2),
              FactoryBadge(
                label: _statusLabel(l10n, booking.status),
                variant: _statusVariant(booking.status),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space2),
          Text(
            l10n.bookedOnLabel(
              formatMonthDayTime(l10n, booking.createdAt.toLocal()),
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: FactorySpacing.space2),
          PaymentStatusChip(bookingId: booking.id),
          if (booking.status == 'COMPLETED')
            ReviewSection(bookingId: booking.id),
          const SizedBox(height: FactorySpacing.space2),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: FactorySpacing.space2,
              children: [
                FactoryButton(
                  label: l10n.messageAboutBookingButton,
                  variant: FactoryButtonVariant.text,
                  onPressed: _openMessageAboutBookingDialog,
                ),
                if (booking.status == 'CONFIRMED')
                  FactoryButton(
                    label: l10n.cancelBookingButton,
                    variant: FactoryButtonVariant.textDanger,
                    isLoading: _isCancelling,
                    onPressed: _isCancelling ? null : _confirmAndCancel,
                  ),
              ],
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            providerId: matched!.providerId,
            providerName: matched.providerName ?? l10n.messagingUnknownBusinessName,
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.messageAboutBookingSentMessage)));
  }

  Future<void> _confirmAndCancel() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.cancelBookingConfirmTitle,
      message: l10n.cancelBookingConfirmMessage,
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
      await ref.read(bookingApiProvider).cancelBooking(widget.booking.id);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorBookingGeneric(e.toString()))),
      );
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
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
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
        _error = l10n.errorMessagingGeneric(e.toString());
        _isSubmitting = false;
      });
    }
  }
}

String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
  'CONFIRMED' => l10n.bookingStatusConfirmed,
  'COMPLETED' => l10n.bookingStatusCompleted,
  'CANCELLED' => l10n.bookingStatusCancelled,
  _ =>
    status.isEmpty
        ? status
        : '${status[0]}${status.substring(1).toLowerCase()}',
};

FactoryBadgeVariant _statusVariant(String status) => switch (status) {
  'CONFIRMED' => FactoryBadgeVariant.available,
  'COMPLETED' => FactoryBadgeVariant.verified,
  'CANCELLED' => FactoryBadgeVariant.error,
  _ => FactoryBadgeVariant.neutral,
};
