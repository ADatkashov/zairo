import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';

/// Which trust/state signal this badge carries — drives its color, not its
/// wording. [verified] is the running trust signal the design system wants
/// visible everywhere a review or booking is (see the artifact's "Verified
/// booking" principle); [available]/[limited] read booking state at a
/// glance; [error] flags a failed/cancelled state (a declined payment, a
/// cancelled booking); [neutral] is for anything else (a plain status label).
enum FactoryBadgeVariant { verified, available, limited, error, neutral }

class FactoryBadge extends StatelessWidget {
  const FactoryBadge({
    super.key,
    required this.label,
    this.variant = FactoryBadgeVariant.neutral,
    this.icon,
    this.showDot = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final FactoryBadgeVariant variant;
  final IconData? icon;

  /// A small leading dot in the label color — the "status chip" look used in
  /// tables, where the dot carries the state when the label is long.
  final bool showDot;

  /// Overrides [variant]'s color pair — for chrome that isn't a
  /// verified/available/limited/error trust signal at all, but a category
  /// identity (e.g. Beauty/Auto/Cleaning on a provider card). Both null
  /// (the default) keeps the original variant-driven behavior.
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    // Tint alpha is 0.08 so the tone-colored label keeps 4.5:1 on its own tint.
    final (Color variantBg, Color variantFg) = switch (variant) {
      FactoryBadgeVariant.verified => (colors.primaryTint, colors.primaryStrong),
      FactoryBadgeVariant.available => (Color.alphaBlend(colors.success.withValues(alpha: 0.08), colors.surface), colors.success),
      FactoryBadgeVariant.limited => (Color.alphaBlend(colors.warning.withValues(alpha: 0.08), colors.surface), colors.warning),
      FactoryBadgeVariant.error => (Color.alphaBlend(colors.error.withValues(alpha: 0.08), colors.surface), colors.error),
      FactoryBadgeVariant.neutral => (colors.surfaceAlt, colors.textSecondary),
    };
    final bg = backgroundColor ?? variantBg;
    final fg = foregroundColor ?? variantFg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space2, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: FactoryRadius.smRadius),
      // Shrinks rather than hard-overflows in a tight card footer — a
      // badge's label length isn't bounded (status text varies), so this
      // can't assume it always has enough room.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            if (icon != null) ...[
              Icon(icon, size: 11, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
