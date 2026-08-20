import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';

/// The star-rating + review-count reference used across the whole system —
/// same widget for a stylist, a mechanic, or a tutor. Carries its own
/// semantic label ("4.9 out of 5, 212 reviews") so a screen reader gets the
/// full meaning, not just the glyph and two numbers.
class FactoryRatingLabel extends StatelessWidget {
  const FactoryRatingLabel({super.key, required this.rating, this.reviewCount, this.iconSize = 13});

  final double rating;
  final int? reviewCount;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final ratingText = rating.toStringAsFixed(1);
    final semanticLabel = reviewCount == null
        ? '$ratingText out of 5'
        : '$ratingText out of 5, $reviewCount reviews';

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: iconSize, color: colors.accent),
          const SizedBox(width: 3),
          Text(ratingText, style: textTheme.labelMedium?.copyWith(color: colors.text, fontWeight: FontWeight.w700)),
          if (reviewCount != null) ...[
            const SizedBox(width: 3),
            Text('($reviewCount)', style: textTheme.labelMedium?.copyWith(color: colors.textTertiary, fontWeight: FontWeight.w400)),
          ],
        ],
      ),
    );
  }
}
