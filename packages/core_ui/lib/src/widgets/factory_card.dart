import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_elevation.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';

/// The generic surfaced container every screen reaches for instead of a
/// bare Material `Card` — border always present (per the design system's
/// elevation table, a card keeps its border at every level, shadow layers
/// on top rather than replacing it). [elevation] defaults to
/// [FactoryElevationLevel.none] — the design system's rule is that resting
/// cards and inline rows read through a border, not a shadow; reach for
/// [FactoryElevationLevel.md] for a card that should look raised even at
/// rest (its worked example: provider/service cards), or [sm]/[lg] for a
/// hover lift / a floating surface respectively.
class FactoryCard extends StatelessWidget {
  const FactoryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FactorySpacing.space4),
    this.elevation = FactoryElevationLevel.none,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final FactoryElevationLevel elevation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: FactoryRadius.lgRadius,
        border: Border.all(color: colors.border),
        boxShadow: context.factoryElevation(elevation),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return ClipRRect(
      borderRadius: FactoryRadius.lgRadius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: card),
      ),
    );
  }
}
