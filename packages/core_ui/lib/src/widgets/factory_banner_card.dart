import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';

/// A full-bleed promo banner: a cover image under a dark scrim with the
/// [title]/[subtitle] on top, an optional corner [tag] ("Ad") and a play badge
/// when the banner opens a video. The cover is a network image; while it loads
/// or if it fails, the card shows a brand gradient so the text stays readable.
class FactoryBannerCard extends StatelessWidget {
  const FactoryBannerCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.tag,
    this.showPlay = false,
    this.playLabel,
    this.onTap,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;

  /// A small label pinned to the top-left corner (the "Ad" mark); null shows none.
  final String? tag;

  /// Draws a play badge: this banner opens a video.
  final bool showPlay;

  /// Spoken for the play badge ("Watch video"); the badge is decoration otherwise.
  final String? playLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    const onImage = Colors.white;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryStrong, colors.primary],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: playLabel != null && showPlay ? '$title, $playLabel' : title,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: FactoryRadius.xlRadius,
        child: Material(
          color: colors.primaryStrong,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
                ),
                // Keeps white text readable on any cover.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xB3000000)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(FactorySpacing.space4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(color: onImage),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: FactorySpacing.space1),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: onImage.withValues(alpha: 0.9)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (tag != null)
                  Positioned(
                    top: FactorySpacing.space3,
                    left: FactorySpacing.space3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: FactoryRadius.smRadius,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space2, vertical: 2),
                        child: Text(tag!, style: textTheme.labelSmall?.copyWith(color: onImage)),
                      ),
                    ),
                  ),
                if (showPlay)
                  Positioned(
                    top: FactorySpacing.space3,
                    right: FactorySpacing.space3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                      child: const Padding(
                        padding: EdgeInsets.all(FactorySpacing.space2),
                        child: Icon(Symbols.play_arrow_rounded, size: 24, fill: 1, color: onImage),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
