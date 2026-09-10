import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/factory_colors.dart';

/// The star-rating + review-count reference used across the whole system —
/// same widget for a stylist, a mechanic, or a tutor. Carries its own
/// semantic label ("4.9 out of 5, 212 reviews") so a screen reader gets the
/// full meaning, not just the glyph and two numbers.
class FactoryRatingLabel extends StatelessWidget {
  const FactoryRatingLabel({
    super.key,
    required this.rating,
    this.reviewCount,
    this.iconSize = 13,
    this.semanticLabel,
  });

  final double rating;
  final int? reviewCount;
  final double iconSize;

  /// core_ui has no app-level localization of its own — callers that show
  /// this app in more than English must pass their own translated label
  /// here (see FactoryProviderCard.ratingSemanticLabel) rather than relying
  /// on the English fallback this widget computes when it's null.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final ratingText = rating.toStringAsFixed(1);
    final effectiveSemanticLabel =
        semanticLabel ??
        (reviewCount == null
            ? '$ratingText out of 5'
            : '$ratingText out of 5, $reviewCount reviews');

    return Semantics(
      label: effectiveSemanticLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The design board always renders the rating star solid
          // (font-variation-settings: 'FILL' 1) — not the empty/filled
          // toggle a multi-star rating INPUT would need.
          Icon(
            Symbols.star_rounded,
            fill: 1,
            size: iconSize,
            color: colors.accent,
          ),
          const SizedBox(width: 3),
          Text(
            ratingText,
            style: textTheme.labelMedium?.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (reviewCount != null) ...[
            const SizedBox(width: 3),
            Text(
              '($reviewCount)',
              style: textTheme.labelMedium?.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
