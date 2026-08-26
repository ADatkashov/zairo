import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';

/// A single-choice list row — pick a master, a mechanic, a vehicle, a
/// payment method. [selected] carries a tinted/bordered card plus a check
/// icon, never color alone (same rule [FactoryTimeSlot] and
/// [FactoryServiceCard] follow for their own selected state). Leave
/// [onTap] null for a plain informational row (e.g. a vehicle list with
/// nothing to select, just a delete action in [trailing]).
class FactorySelectableTile extends StatelessWidget {
  const FactorySelectableTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onTap,
    this.titleColor,
  });

  final String title;

  /// Defaults to the theme's usual title color — set this to dim the title
  /// itself (e.g. `colors.textTertiary`) for a deactivated/removed row,
  /// same idea as [FactoryServiceCard]'s inactive-state dimming.
  final Color? titleColor;

  /// Free-form so callers keep control of subtitle style — a bio reads as
  /// body text, a license plate reads as mono, and this doesn't pick for them.
  final Widget? subtitle;
  final Widget? leading;

  /// Rendered after the selected checkmark (when [selected]) — e.g. a
  /// "view portfolio" icon button that stays visible whether or not this
  /// row is the current pick.
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: FactoryRadius.mdRadius,
        child: Container(
          padding: const EdgeInsets.all(FactorySpacing.space3),
          decoration: BoxDecoration(
            color: selected ? colors.primaryTint : colors.surface,
            borderRadius: FactoryRadius.mdRadius,
            border: Border.all(color: selected ? colors.primary : colors.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: FactorySpacing.space3)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleColor == null ? textTheme.titleSmall : textTheme.titleSmall?.copyWith(color: titleColor),
                    ),
                    if (subtitle != null) ...[const SizedBox(height: 2), subtitle!],
                  ],
                ),
              ),
              if (selected)
                Padding(
                  padding: EdgeInsets.only(left: FactorySpacing.space1, right: trailing != null ? FactorySpacing.space1 : 0),
                  child: Icon(Icons.check_circle_rounded, size: 20, color: colors.primary),
                ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
