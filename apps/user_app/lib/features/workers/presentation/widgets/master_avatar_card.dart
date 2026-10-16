import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../core/formatting/initials.dart';
import '../../../../l10n/app_localizations.dart';

/// A master as a tappable avatar with the name and rating underneath — the unit
/// of Home's "Best masters" rail and Favorites' "My masters" rail.
class MasterAvatarCard extends StatelessWidget {
  const MasterAvatarCard({
    super.key,
    required this.displayName,
    required this.photoUrl,
    required this.averageRating,
    required this.reviewCount,
    required this.onTap,
  });

  static const width = 96.0;
  static const avatarSize = 72.0;

  /// Height of the whole card; follows the text scale so a large system font does not clip the name.
  static double heightFor(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context);
    return avatarSize + FactorySpacing.space2 + textScale.scale(14 * 1.3) * 2 + 4 + textScale.scale(13 * 1.3) + 4;
  }

  final String displayName;
  final String? photoUrl;

  /// Null for a master nobody has reviewed yet: the rating row is left out.
  final double? averageRating;
  final int reviewCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final rating = averageRating;
    return Semantics(
      button: true,
      label: displayName,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: FactoryRadius.mdRadius,
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              FactoryAvatar(
                initials: initialsFor(displayName),
                size: avatarSize,
                image: photoUrl != null ? NetworkImage(photoUrl!) : null,
              ),
              const SizedBox(height: FactorySpacing.space2),
              Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
              ),
              if (rating != null) ...[
                const SizedBox(height: 4),
                // Scales down rather than overflowing the narrow card at a large text size.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: FactoryRatingLabel(
                    rating: rating,
                    reviewCount: reviewCount,
                    semanticLabel: l10n.ratingSemanticLabelWithReviews(rating.toStringAsFixed(1), reviewCount),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
