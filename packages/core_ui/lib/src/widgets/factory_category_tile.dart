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
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
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
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: selected ? colors.primary : colors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: FactoryIconSize.md, color: selected ? colors.onPrimary : colors.textSecondary),
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
