import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_motion.dart';
import '../theme/factory_spacing.dart';

/// The pill filter/category chip — "Today", "Top rated", a filter-sheet
/// trigger. Deliberately a plain [GestureDetector] rather than Flutter's
/// [ChoiceChip]: Material's chip carries its own ripple/sizing opinions
/// that fought the design system's compact pill proportions.
class FactoryChip extends StatelessWidget {
  const FactoryChip({super.key, required this.label, this.selected = false, this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final fg = selected ? colors.onPrimary : colors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: FactoryMotion.fast,
          curve: FactoryMotion.standard,
          padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3 + 1, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? colors.primary : colors.border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
