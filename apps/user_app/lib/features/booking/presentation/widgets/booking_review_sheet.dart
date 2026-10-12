import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/payment_plan.dart';
import 'booking_payment_summary.dart';

/// Everything the customer is about to commit to, gathered before anything is
/// created or charged.
class BookingReviewData {
  const BookingReviewData({
    required this.providerName,
    required this.serviceTitle,
    required this.durationMinutes,
    required this.price,
    required this.currencySymbol,
    required this.startsAt,
    required this.personName,
    required this.plan,
  });

  final String providerName;
  final String serviceTitle;
  final int durationMinutes;
  final double price;
  final String currencySymbol;
  final DateTime? startsAt;

  /// The chosen specialist; null for businesses without people to choose from.
  /// An empty string means "any" was chosen.
  final String? personName;

  /// Null while the deposit policy is unknown: the sheet then shows the plain
  /// price, never a guessed "free".
  final PaymentPlan? plan;
}

/// The last look before the booking is created: service, when, who, where and
/// what is charged now. Resolves true only on "Confirm"; closing the sheet or
/// "Change" resolves false and nothing has been created yet.
Future<bool> showBookingReviewSheet(BuildContext context, BookingReviewData data) async {
  final confirmed = await showFactoryBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ReviewBody(data: data),
  );
  return confirmed ?? false;
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.data});

  final BookingReviewData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final plan = data.plan;
    final chargesNow = plan != null && plan.dueNow > 0;

    final person = data.personName;
    final rows = <Widget>[
      _ReviewRow(
        icon: Symbols.content_cut_rounded,
        label: l10n.bookingReviewServiceLabel,
        value: data.serviceTitle,
        note: l10n.serviceDurationMinutes(data.durationMinutes),
      ),
      _ReviewRow(
        icon: Symbols.event_rounded,
        label: l10n.bookingConfirmationWhenLabel,
        value: data.startsAt == null ? '—' : formatMonthDayTime(l10n, data.startsAt!.toLocal()),
      ),
      if (person != null)
        _ReviewRow(
          icon: Symbols.person_rounded,
          label: l10n.bookingReviewPersonLabel,
          value: person.isEmpty ? l10n.bookingReviewAnyPerson : person,
        ),
      _ReviewRow(
        icon: Symbols.storefront_rounded,
        label: l10n.bookingReviewPlaceLabel,
        value: data.providerName,
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          FactorySpacing.space4,
          FactorySpacing.space2,
          FactorySpacing.space4,
          FactorySpacing.space4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.bookingReviewTitle, style: textTheme.titleLarge),
            const SizedBox(height: FactorySpacing.space4),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: FactorySpacing.space5),
              rows[i],
            ],
            const SizedBox(height: FactorySpacing.space4),
            if (plan != null)
              BookingPaymentSummary(plan: plan)
            else
              Row(
                children: [
                  Expanded(child: Text(l10n.bookingReviewTotal, style: textTheme.bodyMedium)),
                  FactoryPriceText(amount: data.price, currencySymbol: data.currencySymbol, fontSize: 18),
                ],
              ),
            const SizedBox(height: FactorySpacing.space4),
            FactoryButton(
              label: chargesNow ? l10n.bookingReviewConfirmPay : l10n.bookingReviewConfirmFree,
              variant: FactoryButtonVariant.gradient,
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: FactorySpacing.space2),
            FactoryButton(
              label: l10n.bookingReviewChange,
              variant: FactoryButtonVariant.text,
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.icon, required this.label, required this.value, this.note});

  final IconData icon;
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: colors.primaryTint, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: colors.primary),
        ),
        const SizedBox(width: FactorySpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
              Text(value, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              if (note != null) Text(note!, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
