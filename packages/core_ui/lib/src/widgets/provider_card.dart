import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';
import 'factory_badge.dart';
import 'factory_price_text.dart';
import 'factory_rating_label.dart';

/// How a [FactoryProviderCard] arranges itself: [vertical] (image on top —
/// a horizontally-scrolling discovery row) or [horizontal] (image on the
/// left — a search-results list).
enum FactoryProviderCardLayout { vertical, horizontal }

/// The one card every vertical renders a provider through — a salon today,
/// an auto workshop or dental clinic tomorrow. Named `FactoryProviderCard`
/// (the `Factory` prefix every other widget in this package carries), not
/// `SalonCard` or `BeautyProviderCard`: nothing about its API mentions
/// beauty. It doesn't know how to load an image either — [image] is
/// whatever widget the caller already uses for network images in that app,
/// so this package stays free of an image-loading dependency.
class FactoryProviderCard extends StatelessWidget {
  const FactoryProviderCard({
    super.key,
    required this.title,
    this.rating,
    this.reviewCount,
    this.ratingSemanticLabel,
    this.metaText,
    this.priceFrom,
    this.currencySymbol,
    this.availabilityLabel,
    this.image,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.favoriteAddSemanticLabel = 'Add to favorites',
    this.favoriteRemoveSemanticLabel = 'Remove from favorites',
    this.onTap,
    this.layout = FactoryProviderCardLayout.vertical,
    this.width,
  });

  final String title;
  final double? rating;
  final int? reviewCount;

  /// See FactoryRatingLabel.semanticLabel — this app has no localization of
  /// its own to derive the English "out of 5" fallback from another language.
  final String? ratingSemanticLabel;

  /// A short secondary line — typically "1.2 km" or "1.2 km · Almaty".
  final String? metaText;

  final num? priceFrom;

  /// Passed straight through to [FactoryPriceText], which falls back to
  /// [RegionDefaults.currencySymbol] when null — see that widget for why
  /// this isn't a hardcoded literal.
  final String? currencySymbol;

  /// "Today 18:00" or "Available today" — rendered as a badge, not text,
  /// so it reads as state rather than a caption.
  final String? availabilityLabel;

  final Widget? image;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteToggle;

  /// core_ui has no app-level localization of its own — callers that show
  /// this app in more than English must pass their own translated strings
  /// here rather than relying on the English fallback default.
  final String favoriteAddSemanticLabel;
  final String favoriteRemoveSemanticLabel;

  final VoidCallback? onTap;
  final FactoryProviderCardLayout layout;

  /// Only meaningful for [FactoryProviderCardLayout.vertical], where the card
  /// sits in a horizontally-scrolling row and needs a fixed width.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;

    final imageArea = SizedBox(
      width: layout == FactoryProviderCardLayout.horizontal ? 84 : null,
      height: layout == FactoryProviderCardLayout.vertical ? 96 : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: layout == FactoryProviderCardLayout.horizontal
                ? const BorderRadius.horizontal(left: Radius.circular(FactoryRadius.lg))
                : const BorderRadius.vertical(top: Radius.circular(FactoryRadius.lg)),
            child: image ??
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.primaryTint, colors.surfaceAlt],
                    ),
                  ),
                ),
          ),
          if (onFavoriteToggle != null)
            Positioned(
              top: 8,
              right: 8,
              child: _FavoriteButton(
                isFavorite: isFavorite,
                onToggle: onFavoriteToggle!,
                addLabel: favoriteAddSemanticLabel,
                removeLabel: favoriteRemoveSemanticLabel,
              ),
            ),
        ],
      ),
    );

    final body = Padding(
      padding: const EdgeInsets.all(FactorySpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.text),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (rating != null)
                FactoryRatingLabel(
                  rating: rating!,
                  reviewCount: reviewCount,
                  iconSize: 11,
                  semanticLabel: ratingSemanticLabel,
                ),
              if (rating != null && metaText != null) ...[
                const SizedBox(width: 5),
                Text('·', style: TextStyle(color: colors.textTertiary)),
                const SizedBox(width: 5),
              ],
              if (metaText != null)
                Flexible(
                  child: Text(
                    metaText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.textTertiary, fontWeight: FontWeight.w400),
                  ),
                ),
            ],
          ),
          if (priceFrom != null || availabilityLabel != null) ...[
            const SizedBox(height: 6),
            // Wrap, not Row: a narrow vertical card (e.g. a horizontally
            // scrolling discovery rail) can't always fit a price and a
            // longer availability label on one line — this reflows to a
            // second line instead of overflowing, and still reads as one
            // row whenever there's room (the common horizontal-layout case).
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (priceFrom != null)
                  FactoryPriceText(amount: priceFrom!, currencySymbol: currencySymbol, prefix: 'from '),
                if (availabilityLabel != null)
                  FactoryBadge(label: availabilityLabel!, variant: FactoryBadgeVariant.available),
              ],
            ),
          ],
        ],
      ),
    );

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: FactoryRadius.lgRadius,
        border: Border.all(color: colors.border),
      ),
      child: layout == FactoryProviderCardLayout.horizontal
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [imageArea, Expanded(child: body)],
              ),
            )
          : Column(mainAxisSize: MainAxisSize.min, children: [imageArea, body]),
    );

    final tappable = ClipRRect(
      borderRadius: FactoryRadius.lgRadius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: card),
      ),
    );

    return width != null ? SizedBox(width: width, child: tappable) : tappable;
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onToggle,
    required this.addLabel,
    required this.removeLabel,
  });

  final bool isFavorite;
  final ValueChanged<bool> onToggle;
  final String addLabel;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Semantics(
      button: true,
      // container: true gives this its own semantics node — without it,
      // this label silently merges into the whole card's InkWell node
      // (which also picks up the title text), so a screen reader user
      // never gets a distinct, actionable "favorite" control nested
      // inside the card's own tap target.
      container: true,
      label: isFavorite ? removeLabel : addLabel,
      child: GestureDetector(
        onTap: () => onToggle(!isFavorite),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), shape: BoxShape.circle),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 15,
            color: isFavorite ? colors.error : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
