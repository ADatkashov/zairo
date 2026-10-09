import 'package:flutter/material.dart';

import '../theme/factory_app_profile.dart';
import '../theme/factory_colors.dart';
import '../theme/factory_icon_size.dart';
import '../theme/factory_radius.dart';

/// A card holding related settings rows (`ListTile` / `SwitchListTile`), with
/// a hairline between them. Rows keep their own tap targets and semantics;
/// the group only supplies the surface, border and corner radius (from the
/// app profile) and clips the rows' ink ripples to it.
class FactorySettingsGroup extends StatelessWidget {
  const FactorySettingsGroup({super.key, required this.children, this.dividerIndent = 72});

  final List<Widget> children;

  /// Where the hairline starts, so it lines up with the row text rather than
  /// the leading icon. The default fits a 40px [FactoryIconBadge] row.
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.xlRadius;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(color: colors.border),
      ),
      // A Material so the rows' ink is drawn on (and clipped to) this card.
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: dividerIndent, color: colors.border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// The tinted rounded-square icon at the start of a settings row. [color]
/// defaults to the primary color; pass `colors.error` for a
/// destructive row.
class FactoryIconBadge extends StatelessWidget {
  const FactoryIconBadge({super.key, required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final tone = color ?? colors.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Color.alphaBlend(tone.withValues(alpha: 0.12), colors.surface),
        borderRadius: FactoryRadius.mdRadius,
      ),
      child: Icon(icon, size: FactoryIconSize.md, color: tone),
    );
  }
}
