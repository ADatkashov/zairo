import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';
import '../util/factory_strings.dart';
import 'factory_badge.dart';
import 'factory_price_text.dart';
import 'factory_rating_label.dart';

/// How a [FactoryProviderCard] arranges itself: [vertical] (image on top —
/// a horizontally-scrolling discovery row) or [horizontal] (image on the
/// left — a search-results list).
enum FactoryProviderCardLayout { vertical, horizontal }

/// The one card every vertical renders a provider through — a salon, an
/// auto workshop, or (in some future vertical) a dental clinic. Named
/// `FactoryProviderCard`
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
    this.categoryLabel,
    this.categoryColor,
    this.categoryTint,
    this.image,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.favoriteAddSemanticLabel,
    this.favoriteRemoveSemanticLabel,
    this.pricePrefix,
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

  /// A top-left category chip over the photo (e.g. "Beauty") — Customer
  /// App Redesign board, 2026-09-05. All three null (the default) renders
  /// no badge at all, matching every call site that predates this field.
  final String? categoryLabel;
  final Color? categoryColor;
  final Color? categoryTint;

  final Widget? image;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteToggle;

  /// core_ui has no app-level localization of its own — callers that show
  /// this app in more than English must pass their own translated strings
  /// here rather than relying on the English fallback default.
  final String? favoriteAddSemanticLabel;
  final String? favoriteRemoveSemanticLabel;

  /// Leads the [priceFrom] amount ("from 8 000 ₸"). Null uses the built-in
  /// localized word from [FactoryStrings].
  final String? pricePrefix;

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
      height: layout == FactoryProviderCardLayout.vertical ? 128 : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: layout == FactoryProviderCardLayout.horizontal
                ? const BorderRadius.horizontal(
                    left: Radius.circular(FactoryRadius.xl),
                  )
                : const BorderRadius.vertical(
                    top: Radius.circular(FactoryRadius.xl),
                  ),
            child:
                image ??
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
          if (categoryLabel != null &&
              categoryColor != null &&
              categoryTint != null)
            // left+right (not just left): the badge is bounded by the photo's
            // width, so on the 84px photo of a horizontal card FactoryBadge's
            // FittedBox shrinks the label instead of it being clipped ("Beaut").
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: FactoryBadge(
                  label: categoryLabel!,
                  backgroundColor: categoryTint,
                  foregroundColor: categoryColor,
                ),
              ),
            ),
          if (onFavoriteToggle != null)
            Positioned(
              top: 4,
              right: 4,
              child: _FavoriteButton(
                isFavorite: isFavorite,
                onToggle: onFavoriteToggle!,
                addLabel: favoriteAddSemanticLabel ?? FactoryStrings.of(context).addToFavorites,
                removeLabel: favoriteRemoveSemanticLabel ?? FactoryStrings.of(context).removeFromFavorites,
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
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: colors.text),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (rating != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: FactoryRatingLabel(
                      rating: rating!,
                      reviewCount: reviewCount,
                      iconSize: 11,
                      semanticLabel: ratingSemanticLabel,
                    ),
                  ),
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
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
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
                  FactoryPriceText(
                    amount: priceFrom!,
                    currencySymbol: currencySymbol,
                    prefix: pricePrefix ?? FactoryStrings.of(context).priceFrom,
                  ),
                if (availabilityLabel != null)
                  FactoryBadge(
                    label: availabilityLabel!,
                    variant: FactoryBadgeVariant.available,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: FactoryRadius.xlRadius,
        border: Border.all(color: colors.border),
      ),
      child: layout == FactoryProviderCardLayout.horizontal
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  imageArea,
                  Expanded(child: body),
                ],
              ),
            )
          : Column(mainAxisSize: MainAxisSize.min, children: [imageArea, body]),
    );

    final tappable = ClipRRect(
      borderRadius: FactoryRadius.xlRadius,
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
    return Semantics(
      button: true,
      // container: true gives this its own semantics node — without it,
      // this label silently merges into the whole card's InkWell node
      // (which also picks up the title text), so a screen reader user
      // never gets a distinct, actionable "favorite" control nested
      // inside the card's own tap target.
      container: true,
      label: isFavorite ? removeLabel : addLabel,
      // Padding inside the detector widens the tap area to 44x44 without
      // growing the visible 36px circle.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onToggle(!isFavorite),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.favorite_rounded,
              fill: isFavorite ? 1 : 0,
              size: 18,
              // The disc behind is always translucent white, so the icon uses
              // fixed light-theme tones (the dark theme's pale ones would vanish).
              color: isFavorite
                  ? const Color(0xFFB3372E)
                  : const Color(0xFF5C564C),
            ),
          ),
        ),
      ),
    );
  }
}
