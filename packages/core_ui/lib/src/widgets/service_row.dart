import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
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
    this.currencySymbol = '₸',
    this.onTap,
    this.showDivider = true,
  });

  final String title;

  /// "90 min" or "90 min · Aigerim K.".
  final String metaText;
  final num price;
  final String currencySymbol;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space3),
        decoration: showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))) : null,
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
          ],
        ),
      ),
    );
  }
}
