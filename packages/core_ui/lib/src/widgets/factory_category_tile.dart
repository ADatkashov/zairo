import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_icon_size.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';

/// An icon-forward category selector — "Haircut", "Beauty", "Auto" — a
/// circle icon over a short label, unlike [FactoryChip]'s pill (text-first,
/// for filters/sort) or [FactorySelectableTile]'s row (leading icon,
/// title/subtitle, for list content). Reach for this specifically for a
/// horizontal row of top-level categories on a discovery screen.
class FactoryCategoryTile extends StatelessWidget {
  const FactoryCategoryTile({
    super.key,
    required this.icon,
    required this.label,
    this.emoji,
    this.selected = false,
    this.onTap,
    this.accentColor,
    this.accentTint,
  });

  final IconData icon;
  final String label;

  /// When set, rendered instead of [icon] — the master catalog stores an
  /// emoji per category/sphere so a platform admin can add a brand-new one
  /// without a Material icon existing for it in this app's code. [icon]
  /// stays required as the fallback for rows that predate that field.
  final String? emoji;
  final bool selected;
  final VoidCallback? onTap;

  /// Per-category brand chrome (Customer App Redesign board, 2026-09-05) —
  /// e.g. coral for Beauty, lavender for Auto. Both null (the default, and
  /// the only option a category with no mapped accent has — see
  /// `colorForCategory` in user_app) falls back to the original neutral
  /// primary/surfaceAlt treatment, so this stays forward-compatible with
  /// any catalog code that isn't one of the small set of known verticals.
  final Color? accentColor;
  final Color? accentTint;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final hasAccent = accentColor != null && accentTint != null;

    final Color fill;
    final Color iconColor;
    if (selected) {
      fill = accentColor ?? colors.primary;
      iconColor = colors.onPrimary;
    } else if (hasAccent) {
      fill = accentTint!;
      iconColor = accentColor!;
    } else {
      fill = colors.surfaceAlt;
      iconColor = colors.textSecondary;
    }

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: FactoryRadius.lgRadius,
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: fill, borderRadius: FactoryRadius.lgRadius),
                child: emoji != null
                    ? Text(emoji!, style: const TextStyle(fontSize: FactoryIconSize.md))
                    : Icon(icon, size: FactoryIconSize.md, color: iconColor),
              ),
              const SizedBox(height: FactorySpacing.space2),
              SizedBox(
                width: 64,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: selected ? colors.text : colors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
