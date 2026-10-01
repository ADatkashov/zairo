import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../discovery/data/models/service_summary.dart';
import '../../../loyalty/presentation/screens/business_loyalty_screen.dart';
import '../../../payments/presentation/widgets/payment_status_chip.dart';
import '../../data/models/booking.dart';
import 'my_bookings_screen.dart';

/// Board 19 (v2 design audit) — the booking flow previously ended with a
/// snackbar and a `pop()` back to Search/Home, which meant "was this
/// actually booked?" only ever got answered for a second. This screen
/// replaces the provider-detail route so there is a durable, shareable
/// confirmation with the details a customer would screenshot.
class BookingConfirmationScreen extends StatelessWidget {
  final Booking booking;
  final String providerId;
  final String providerName;
  final String providerVertical;
  final ServiceSummary service;
  final DateTime? slotStartsAt;

  const BookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.providerId,
    required this.providerName,
    required this.providerVertical,
    required this.service,
    required this.slotStartsAt,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                children: [
                  const SizedBox(height: FactorySpacing.space6),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Symbols.check_circle_rounded,
                        size: 48,
                        color: colors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space4),
                  Text(
                    l10n.bookingConfirmationTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: FactorySpacing.space1),
                  Text(
                    l10n.bookingConfirmationSubtitle(providerName),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space6),
                  FactoryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ConfirmationRow(
                          icon: switch (providerVertical) {
                            'auto' => Symbols.directions_car_filled_rounded,
                            'cleaning' => Symbols.cleaning_services_rounded,
                            _ => Symbols.content_cut_rounded,
                          },
                          label: providerName,
                          value: service.title,
                        ),
                        const Divider(height: FactorySpacing.space6),
                        _ConfirmationRow(
                          icon: Symbols.event_rounded,
                          label: l10n.bookingConfirmationWhenLabel,
                          value: slotStartsAt == null
                              ? '—'
                              : formatMonthDayTime(l10n, slotStartsAt!.toLocal()),
                        ),
                        const Divider(height: FactorySpacing.space6),
                        if (booking.depositAmount != null &&
                            booking.remainingAmount != null) ...[
                          Container(
                            padding: const EdgeInsets.all(FactorySpacing.space3),
                            decoration: BoxDecoration(
                              color: colors.surfaceAlt,
                              borderRadius: FactoryRadius.mdRadius,
                              border: Border.all(color: colors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.paymentBreakdownTitle,
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: FactorySpacing.space3),
                                _PaymentBreakdownItem(
                                  label: l10n.paymentDepositAmount,
                                  amount: booking.depositAmount!,
                                  description: 'Due now',
                                  isHighlight: true,
                                ),
                                const SizedBox(height: FactorySpacing.space2),
                                _PaymentBreakdownItem(
                                  label: l10n.paymentRemainingAmount,
                                  amount: booking.remainingAmount!,
                                  description: l10n.paymentRemainingInfo,
                                ),
                                const SizedBox(height: FactorySpacing.space2),
                                _PaymentBreakdownVisualizer(
                                  depositAmount: booking.depositAmount!,
                                  remainingAmount: booking.remainingAmount!,
                                  totalAmount: booking.totalPrice,
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: FactorySpacing.space6),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.bookingConfirmationTotalLabel,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            FactoryPriceText(
                              amount: booking.totalPrice,
                              fontSize: 16,
                              weight: FontWeight.w700,
                            ),
                          ],
                        ),
                        const SizedBox(height: FactorySpacing.space2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: PaymentStatusChip(bookingId: booking.id),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FactoryButton(
                      variant: FactoryButtonVariant.secondary,
                      icon: Symbols.workspace_premium_rounded,
                      label: l10n.loyaltyEntryTileTitle,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BusinessLoyaltyScreen(
                            providerId: providerId,
                            providerName: providerName,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              child: Column(
                children: [
                  FactoryButton(
                    label: l10n.bookingConfirmationViewBookingsButton,
                    variant: FactoryButtonVariant.primary,
                    expand: true,
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                      (route) => route.isFirst,
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space2),
                  FactoryButton(
                    label: l10n.bookingConfirmationBackHomeButton,
                    variant: FactoryButtonVariant.text,
                    expand: true,
                    onPressed: () =>
                        Navigator.of(context).popUntil((route) => route.isFirst),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConfirmationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.textSecondary),
        const SizedBox(width: FactorySpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                value,
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentBreakdownItem extends StatelessWidget {
  final String label;
  final double amount;
  final String description;
  final bool isHighlight;

  const _PaymentBreakdownItem({
    required this.label,
    required this.amount,
    required this.description,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
                color: isHighlight ? colors.text : colors.textSecondary,
              ),
            ),
            FactoryPriceText(
              amount: amount,
              fontSize: 14,
              weight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: textTheme.bodySmall?.copyWith(
            color: colors.textTertiary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _PaymentBreakdownVisualizer extends StatelessWidget {
  final double depositAmount;
  final double remainingAmount;
  final double totalAmount;

  const _PaymentBreakdownVisualizer({
    required this.depositAmount,
    required this.remainingAmount,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final depositPercentage = totalAmount > 0 ? (depositAmount / totalAmount) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Expanded(
                flex: depositPercentage.toInt().clamp(0, 100),
                child: Container(
                  height: 20,
                  color: colors.primary,
                ),
              ),
              Expanded(
                flex: (100 - depositPercentage.toInt()).clamp(0, 100),
                child: Container(
                  height: 20,
                  color: colors.surfaceAlt,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Now (${depositPercentage.toStringAsFixed(0)}%)',
              style: textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            Text(
              'On service day',
              style: textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
