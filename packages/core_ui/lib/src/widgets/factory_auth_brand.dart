import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_elevation.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';
import 'factory_logomark.dart';

/// The brand block at the top of the sign-in screens of all three apps: the
/// logomark on a soft gradient tile with an ambient glow, and an optional
/// title and subtitle underneath. One widget so the apps open the same way.
class FactoryAuthBrand extends StatelessWidget {
  const FactoryAuthBrand({super.key, this.title, this.subtitle, this.markSize = 56});

  final String? title;
  final String? subtitle;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final tile = markSize + FactorySpacing.space6 * 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Decorative: the glow and tile carry no information.
        ExcludeSemantics(
          child: SizedBox.square(
            dimension: tile + 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.accent.withValues(alpha: 0.30),
                        colors.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: SizedBox.square(dimension: tile + 40),
                ),
                Container(
                  width: tile,
                  height: tile,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.primaryTint, colors.surface],
                    ),
                    borderRadius: FactoryRadius.xxlRadius,
                    border: Border.all(color: colors.border),
                    boxShadow: context.factoryElevation(FactoryElevationLevel.md),
                  ),
                  child: FactoryLogomark(size: markSize),
                ),
              ],
            ),
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: FactorySpacing.space2),
          Text(title!, textAlign: TextAlign.center, style: textTheme.headlineSmall),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: FactorySpacing.space2),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}
