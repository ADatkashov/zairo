import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';

/// The "N points expiring soon" hint -- shared between a My Rewards row and
/// the business loyalty screen's own banner, both driven by the same
/// `pointsExpiringSoon30d` field.
class PointsExpiringBanner extends StatelessWidget {
  final int points;

  const PointsExpiringBanner({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space2),
      decoration: BoxDecoration(
        color: Color.alphaBlend(colors.warning.withValues(alpha: 0.12), colors.surface),
        borderRadius: FactoryRadius.mdRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.schedule_rounded, size: 16, color: colors.warning),
          const SizedBox(width: FactorySpacing.space2),
          Flexible(
            child: Text(
              l10n.loyaltyPointsExpiringSoon30d(points),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.warning, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
