import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';

/// Which trust/state signal this badge carries — drives its color, not its
/// wording. [verified] is the running trust signal the design system wants
/// visible everywhere a review or booking is (see the artifact's "Verified
/// booking" principle); [available]/[limited] read booking state at a
/// glance; [neutral] is for anything else (a plain status label).
enum FactoryBadgeVariant { verified, available, limited, neutral }

class FactoryBadge extends StatelessWidget {
  const FactoryBadge({super.key, required this.label, this.variant = FactoryBadgeVariant.neutral, this.icon});

  final String label;
  final FactoryBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final (Color bg, Color fg) = switch (variant) {
      FactoryBadgeVariant.verified => (colors.primaryTint, colors.primaryStrong),
      FactoryBadgeVariant.available => (Color.alphaBlend(colors.success.withValues(alpha: 0.14), colors.surface), colors.success),
      FactoryBadgeVariant.limited => (Color.alphaBlend(colors.warning.withValues(alpha: 0.16), colors.surface), colors.warning),
      FactoryBadgeVariant.neutral => (colors.surfaceAlt, colors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space2, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: FactoryRadius.smRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
