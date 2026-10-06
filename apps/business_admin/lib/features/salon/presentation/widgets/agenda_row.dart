import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/schedule_entry.dart';

/// Label and badge variant for a booking status as the owner sees it.
(String, FactoryBadgeVariant) bookingStatusBadge(AppLocalizations l10n, String status) => switch (status) {
  'CONFIRMED' => (l10n.bookingStatusConfirmed, FactoryBadgeVariant.available),
  'COMPLETED' => (l10n.bookingStatusCompleted, FactoryBadgeVariant.verified),
  'PENDING_PAYMENT' => (l10n.bookingStatusPendingPayment, FactoryBadgeVariant.limited),
  'NO_SHOW' => (l10n.bookingStatusNoShow, FactoryBadgeVariant.error),
  _ => (l10n.bookingStatusPending, FactoryBadgeVariant.neutral),
};

/// One booking in an agenda: start time, service (and business when the owner
/// has several), status badge. [compact] drops the time column's width and
/// stacks the badge under the title, for narrow calendar day columns.
class AgendaRow extends StatelessWidget {
  const AgendaRow({super.key, required this.item, this.showProvider = false, this.compact = false});

  final AgendaItem item;
  final bool showProvider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final (label, variant) = bookingStatusBadge(l10n, item.entry.status);
    final time = Text(
      DateFormat.Hm(locale).format(item.entry.startsAt.toLocal()),
      style: FactoryTypography.mono(size: compact ? 12 : 14, color: colors.text),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.serviceTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleSmall),
        if (showProvider)
          Text(
            item.providerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
      ],
    );
    final bar = Container(
      width: 3,
      height: compact ? 44 : 32,
      decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(2)),
    );

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar,
          const SizedBox(width: FactorySpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [time, details, const SizedBox(height: 2), FactoryBadge(label: label, variant: variant)],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 52, child: time),
        bar,
        const SizedBox(width: FactorySpacing.space3),
        Expanded(child: details),
        const SizedBox(width: FactorySpacing.space2),
        FactoryBadge(label: label, variant: variant),
      ],
    );
  }
}
