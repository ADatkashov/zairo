import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../payments/data/models/payment.dart';
import '../../../payments/data/models/saved_card.dart';
import '../../../payments/data/payment_exception.dart';
import '../../../payments/presentation/providers/payments_providers.dart';
import '../../../payments/presentation/screens/saved_cards_screen.dart' show savedCardLabel;
import '../../data/models/booking.dart';
import '../../data/models/payment_plan.dart';
import '../providers/booking_providers.dart';
import '../widgets/booking_stepper.dart';
import 'booking_confirmation_screen.dart';

/// What the payment route (`AppRoutes.bookingPayment`) needs, handed over as
/// the route's `extra`.
class BookingPaymentArgs {
  const BookingPaymentArgs({required this.booking, this.confirmation, this.payment, this.fromReturn = false});

  /// The booking being paid for (it is awaiting payment).
  final Booking booking;

  /// Shown once the payment is confirmed. Null when the screen was opened
  /// from the bookings list, which simply pops back with `true`.
  final BookingConfirmationArgs? confirmation;

  /// The payment the booking flow has just created, so it is not created twice.
  final Payment? payment;

  /// Opened because the customer came back from the payment page (deep link
  /// `zairo://app/payment-result`): only reads where the payment stands — it
  /// never starts a new payment and never re-opens the payment page.
  final bool fromReturn;
}

/// The confirmation details the booking flow had when it sent the customer to
/// pay, by booking id. Coming back from the payment page can replace the whole
/// navigation stack (the deep link opens a fresh route), so the screen that
/// shows "Booking confirmed!" finds the details here instead of losing them.
final pendingConfirmationsProvider = Provider<Map<String, BookingConfirmationArgs>>((ref) => {});

enum _Phase { starting, choose, waiting, failed, expired }

/// Pays for a booking with a redirect-based provider (Freedom Pay): opens the
/// provider's payment page in the browser, then waits here until the *server*
/// reports the booking confirmed. The customer coming back from the payment
/// page proves nothing — the provider's webhook is the only source of truth —
/// so this screen polls (and re-checks the moment the app is resumed) rather
/// than trusting a return link.
class BookingPaymentScreen extends ConsumerStatefulWidget {
  const BookingPaymentScreen({super.key, required this.args});

  final BookingPaymentArgs args;

  @override
  ConsumerState<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends ConsumerState<BookingPaymentScreen> with WidgetsBindingObserver {
  /// A bit longer than the backend's unpaid-booking timeout (15 minutes), after
  /// which the booking is released anyway.
  static const _maxWait = Duration(minutes: 16);

  final _startedAt = DateTime.now();
  _Phase _phase = _Phase.starting;
  Payment? _payment;
  Timer? _timer;
  bool _polling = false;
  bool _busy = false;
  bool _finished = false;
  String? _problem;

  /// Saved cards the customer can pay with, and the one picked (null = the payment page).
  List<SavedCard> _cards = const [];
  String? _selectedCardId;

  Booking get _booking => widget.args.booking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _payment = widget.args.payment;
    // After the first frame: starting needs the screen's context (localizations).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final confirmation = widget.args.confirmation;
      if (confirmation != null) {
        ref.read(pendingConfirmationsProvider)[_booking.id] = confirmation;
      }
      _start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the browser: ask the server right away instead of waiting for the next tick.
    if (state == AppLifecycleState.resumed && (_phase == _Phase.waiting || _phase == _Phase.expired)) {
      _poll();
    }
  }

  Future<void> _start() async {
    try {
      if (widget.args.fromReturn) {
        // Back from the payment page: read where the payment stands, nothing else.
        final payment = await ref.read(paymentsApiProvider).getPayment(_booking.id);
        if (!mounted) return;
        if (payment == null) {
          setState(() => _phase = _Phase.failed);
        } else {
          await _apply(payment, launch: false);
        }
        return;
      }
      final payment = _payment ?? await _currentOrNewPayment();
      if (!mounted) return;
      if (payment == null) {
        // The customer has saved cards: let them pick one instead of going to the payment page.
        setState(() => _phase = _Phase.choose);
        return;
      }
      await _apply(payment, launch: true);
    } on PaymentException {
      // 409: the booking is no longer awaiting payment — it was paid or released meanwhile.
      await _poll();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _problem = AppLocalizations.of(context)!.paymentStartError;
      });
    }
  }

  /// Reuses a payment that is already waiting for the customer (or just
  /// reads back one that finished) rather than starting a second charge.
  ///
  /// Returns null when the customer should first choose how to pay (they have
  /// saved cards that can be charged right away).
  Future<Payment?> _currentOrNewPayment() async {
    final api = ref.read(paymentsApiProvider);
    final existing = await api.getPayment(_booking.id);
    if (existing != null && existing.status != 'FAILED') return existing;
    final cards = await usableSavedCards(api);
    if (cards.isNotEmpty) {
      _cards = cards;
      _selectedCardId ??= cards.first.id;
      return null;
    }
    return api.createPayment(_booking.id);
  }

  /// Pays with the card picked on the choose step — or on the payment page when none is picked.
  Future<void> _payChosen() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final api = ref.read(paymentsApiProvider);
      final cardId = _selectedCardId;
      final payment = cardId == null
          ? await api.createPayment(_booking.id)
          : await api.payWithSavedCard(_booking.id, cardId);
      if (!mounted) return;
      await _apply(payment, launch: cardId == null);
    } on PaymentException {
      await _poll();
    } catch (_) {
      if (mounted) setState(() => _problem = AppLocalizations.of(context)!.paymentStartError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(Payment payment, {required bool launch}) async {
    _payment = payment;
    if (payment.status == 'FAILED') {
      _timer?.cancel();
      setState(() {
        _phase = _Phase.failed;
        _problem = null;
      });
      return;
    }
    setState(() {
      _phase = _Phase.waiting;
      _problem = null;
    });
    if (payment.status == 'PENDING' && launch) await _openCheckout();
    _timer?.cancel();
    _timer = Timer.periodic(ref.read(paymentPollIntervalProvider), (_) => _poll());
    // A payment that is already SUCCEEDED confirms the booking right away.
    if (payment.status != 'PENDING') await _poll();
  }

  Future<void> _openCheckout() async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.tryParse(_payment?.checkoutUrl ?? '');
    // Only ever hand the browser an https page — the URL comes from a server response.
    if (uri == null || uri.scheme != 'https') {
      setState(() => _problem = l10n.paymentOpenFailed);
      return;
    }
    bool opened;
    try {
      opened = await ref.read(checkoutLauncherProvider)(uri);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _problem = opened ? null : l10n.paymentOpenFailed);
  }

  /// Asks the server where the booking and its payment stand. Returns whether
  /// the booking is now confirmed.
  Future<bool> _poll() async {
    if (_finished || _polling) return false;
    _polling = true;
    try {
      final booking = await ref.read(bookingApiProvider).getBooking(_booking.id);
      if (!mounted || _finished) return false;
      switch (booking.status) {
        case 'PENDING_PAYMENT' || 'PENDING':
          break;
        case 'CANCELLED' || 'NO_SHOW':
          _timer?.cancel();
          setState(() => _phase = _Phase.expired);
          return false;
        default:
          _complete(booking);
          return true;
      }
      final payment = await ref.read(paymentsApiProvider).getPayment(_booking.id);
      if (!mounted || _finished) return false;
      if (payment != null) _payment = payment;
      if (payment?.status == 'FAILED') {
        _timer?.cancel();
        setState(() => _phase = _Phase.failed);
      } else if (DateTime.now().difference(_startedAt) > _maxWait) {
        _timer?.cancel();
        setState(() => _phase = _Phase.expired);
      }
    } catch (_) {
      // A dropped connection must not end the wait — the next tick tries again.
    } finally {
      _polling = false;
    }
    return false;
  }

  void _complete(Booking booking) {
    _finished = true;
    _timer?.cancel();
    ref.invalidate(myBookingsProvider(booking.userId));
    ref.invalidate(paymentForBookingProvider(booking.id));
    final confirmation = widget.args.confirmation ?? ref.read(pendingConfirmationsProvider).remove(booking.id);
    if (confirmation != null) {
      context.pushReplacement(AppRoutes.bookingConfirmation, extra: confirmation.withBooking(booking));
    } else if (context.canPop()) {
      context.pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.paymentConfirmedSnack)),
      );
      context.go(AppRoutes.bookings);
    }
  }

  Future<void> _retry() async {
    if (_cards.isNotEmpty) {
      // Pick again: the same card, another one, or the payment page.
      setState(() {
        _phase = _Phase.choose;
        _problem = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final payment = await ref.read(paymentsApiProvider).createPayment(_booking.id);
      if (!mounted) return;
      await _apply(payment, launch: true);
    } on PaymentException {
      await _poll();
    } catch (_) {
      if (mounted) setState(() => _problem = AppLocalizations.of(context)!.paymentStartError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkNow() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final confirmed = await _poll();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!confirmed && !_finished && _phase == _Phase.waiting) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paymentNotConfirmedYet)));
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go(AppRoutes.bookings);
    }
  }

  Widget _buildChooser(BuildContext context, double amount) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: Text(l10n.paymentScreenTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            const BookingStepper(step: 2),
            const SizedBox(height: FactorySpacing.space4),
            Center(child: FactoryPriceText(amount: amount, fontSize: 28, weight: FontWeight.w800)),
            const SizedBox(height: FactorySpacing.space4),
            Text(l10n.paymentChooseTitle, style: textTheme.titleMedium),
            const SizedBox(height: FactorySpacing.space2),
            RadioGroup<String?>(
              groupValue: _selectedCardId,
              onChanged: (value) => setState(() => _selectedCardId = value),
              child: Column(
                children: [
                  for (final card in _cards)
                    RadioListTile<String?>(
                      value: card.id,
                      title: Text(savedCardLabel(l10n, card)),
                      secondary: const Icon(Symbols.credit_card_rounded),
                    ),
                  RadioListTile<String?>(
                    value: null,
                    title: Text(l10n.paymentChooseOtherCard),
                    secondary: const Icon(Symbols.open_in_new_rounded),
                  ),
                ],
              ),
            ),
            if (_problem != null) ...[
              const SizedBox(height: FactorySpacing.space3),
              Text(_problem!, textAlign: TextAlign.center, style: textTheme.bodySmall?.copyWith(color: colors.error)),
            ],
            const SizedBox(height: FactorySpacing.space4),
            FactoryButton(
              label: l10n.paymentChoosePayButton,
              expand: true,
              isLoading: _busy,
              onPressed: _busy ? null : _payChosen,
            ),
            const SizedBox(height: FactorySpacing.space2),
            FactoryButton(
              label: l10n.paymentCloseButton,
              variant: FactoryButtonVariant.text,
              expand: true,
              onPressed: _close,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    final plan = PaymentPlan.fromAmounts(total: _booking.totalPrice, deposit: _booking.depositAmount);
    final amount = _payment?.amount ?? (plan.dueNow > 0 ? plan.dueNow : _booking.totalPrice);
    final canOpenPage = _payment?.status == 'PENDING' && (_payment?.checkoutUrl ?? '').isNotEmpty;

    if (_phase == _Phase.choose) {
      return _buildChooser(context, amount);
    }

    final (IconData icon, Color tone, String title, String body) = switch (_phase) {
      _Phase.starting || _Phase.waiting || _Phase.choose => (
        Symbols.hourglass_top_rounded,
        colors.primary,
        l10n.paymentWaitingTitle,
        l10n.paymentWaitingBody,
      ),
      _Phase.failed => (Symbols.error_rounded, colors.error, l10n.paymentFailedTitle, l10n.paymentFailedBody),
      _Phase.expired => (Symbols.schedule_rounded, colors.textSecondary, l10n.paymentExpiredTitle, l10n.paymentExpiredBody),
    };

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: Text(l10n.paymentScreenTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            const BookingStepper(step: 2),
            const SizedBox(height: FactorySpacing.space6),
            Center(
              child: _phase == _Phase.starting
                  ? const SizedBox(width: 48, height: 48, child: CircularProgressIndicator())
                  : Icon(icon, size: 56, color: tone),
            ),
            const SizedBox(height: FactorySpacing.space4),
            Text(title, textAlign: TextAlign.center, style: textTheme.headlineSmall),
            const SizedBox(height: FactorySpacing.space2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: FactorySpacing.space4),
            Center(child: FactoryPriceText(amount: amount, fontSize: 28, weight: FontWeight.w800)),
            if (_problem != null) ...[
              const SizedBox(height: FactorySpacing.space3),
              Text(_problem!, textAlign: TextAlign.center, style: textTheme.bodySmall?.copyWith(color: colors.error)),
            ],
            const SizedBox(height: FactorySpacing.space6),
            if (_phase == _Phase.waiting) ...[
              if (canOpenPage)
                FactoryButton(label: l10n.paymentOpenPageButton, expand: true, onPressed: _busy ? null : _openCheckout),
              const SizedBox(height: FactorySpacing.space2),
              FactoryButton(
                label: l10n.paymentCheckStatusButton,
                variant: FactoryButtonVariant.secondary,
                expand: true,
                isLoading: _busy,
                onPressed: _busy ? null : _checkNow,
              ),
            ],
            if (_phase == _Phase.failed)
              FactoryButton(label: l10n.paymentRetryButton, expand: true, isLoading: _busy, onPressed: _busy ? null : _retry),
            if (_phase == _Phase.expired)
              FactoryButton(
                label: l10n.paymentCheckStatusButton,
                expand: true,
                isLoading: _busy,
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await _poll();
                        if (mounted) setState(() => _busy = false);
                      },
              ),
            const SizedBox(height: FactorySpacing.space2),
            FactoryButton(
              label: l10n.paymentCloseButton,
              variant: FactoryButtonVariant.text,
              expand: true,
              onPressed: _close,
            ),
          ],
        ),
      ),
    );
  }
}
