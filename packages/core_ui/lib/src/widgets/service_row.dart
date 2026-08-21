import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';
import 'factory_price_text.dart';

/// A bookable line item — a haircut today, an oil change or a lesson hour
/// tomorrow. Duration/meta on the left, price on the right; nothing here
/// is beauty-specific.
class ServiceRow extends StatelessWidget {
  const ServiceRow({
    super.key,
    required this.title,
    required this.metaText,
    required this.price,
    this.currencySymbol,
    this.onTap,
    this.showDivider = true,
    this.selected = false,
  });

  final String title;

  /// "90 min" or "90 min · Aigerim K.".
  final String metaText;
  final num price;

  /// Passed straight through to FactoryPriceText, which resolves its own
  /// default currency when this is null.
  final String? currencySymbol;
  final VoidCallback? onTap;
  final bool showDivider;

  /// Picked in a single-choice service list (e.g. booking flow). Carried by
  /// a bordered/tinted card plus a check icon, not color alone — same rule
  /// FactoryTimeSlot follows for its own selected state.
  final bool selected;

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
          padding: selected
              ? const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space3)
              : const EdgeInsets.symmetric(vertical: FactorySpacing.space3),
          decoration: selected
              ? BoxDecoration(
                  color: colors.primaryTint,
                  borderRadius: FactoryRadius.mdRadius,
                  border: Border.all(color: colors.primary, width: 1.5),
                )
              : (showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))) : null),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: textTheme.titleSmall?.copyWith(color: colors.text)),
                    const SizedBox(height: 2),
                    Text(metaText, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
                  ],
                ),
              ),
              FactoryPriceText(amount: price, currencySymbol: currencySymbol, fontSize: 14),
              if (selected) ...[
                const SizedBox(width: FactorySpacing.space2),
                Icon(Icons.check_circle_rounded, size: 20, color: colors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
