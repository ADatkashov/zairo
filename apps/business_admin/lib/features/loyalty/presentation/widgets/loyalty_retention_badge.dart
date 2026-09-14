import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// [LoyaltyCustomerInsight.retentionStatus] is a read-through to Customer
/// Intelligence's own classification, not a closed set this feature owns --
/// the known values today are `NEW`/`ACTIVE`/`AT_RISK`/`DUE_FOR_REBOOKING`/
/// `LOST`, each mapped to a real label/color below, but a value this app
/// doesn't recognize yet still renders as a plain neutral badge showing the
/// raw wire text, rather than crashing the roster.
class LoyaltyRetentionBadge extends StatelessWidget {
  final String? status;

  const LoyaltyRetentionBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final value = status;
    if (value == null) return const SizedBox.shrink();
    return FactoryBadge(label: _label(l10n, value), variant: _variant(value));
  }

  String _label(AppLocalizations l10n, String status) => switch (status) {
        'NEW' => l10n.loyaltyRetentionNew,
        'ACTIVE' => l10n.loyaltyRetentionActive,
        'AT_RISK' => l10n.loyaltyRetentionAtRisk,
        'DUE_FOR_REBOOKING' => l10n.loyaltyRetentionDueForRebooking,
        'LOST' => l10n.loyaltyRetentionLost,
        final other => other,
      };

  FactoryBadgeVariant _variant(String status) => switch (status) {
        'NEW' => FactoryBadgeVariant.verified,
        'ACTIVE' => FactoryBadgeVariant.available,
        'AT_RISK' => FactoryBadgeVariant.limited,
        'DUE_FOR_REBOOKING' => FactoryBadgeVariant.limited,
        'LOST' => FactoryBadgeVariant.error,
        _ => FactoryBadgeVariant.neutral,
      };
}
