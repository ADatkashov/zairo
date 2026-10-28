import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/ad_banner.dart';

/// Home's promo banners as a rounded card under the main actions (search,
/// categories): one banner per page, swipe to change, page dots under the card.
/// Promos come after what people came to do, not in front of it.
class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({
    super.key,
    required this.banners,
    required this.onOpenVideo,
    required this.onOpenLink,
  });

  final List<AdBanner> banners;

  /// Called for a banner that has a video (the video wins over a link).
  final ValueChanged<AdBanner> onOpenVideo;

  /// Called for a banner without a video that points at a screen of the app; a banner with neither does nothing on tap.
  final ValueChanged<AdLinkTarget> onOpenLink;

  /// Tall enough for a title and subtitle on the cover, short enough that the
  /// next section starts on the same screen.
  static const height = 148.0;

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final banners = widget.banners;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: HomeBannerCarousel.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final banner = banners[index];
              return FactoryBannerCard(
                imageUrl: banner.imageUrl,
                title: banner.title,
                subtitle: banner.subtitle,
                tag: banner.sponsored ? l10n.adSponsoredLabel : null,
                showPlay: banner.hasVideo,
                playLabel: l10n.adWatchVideoLabel,
                onTap: banner.hasVideo
                    ? () => widget.onOpenVideo(banner)
                    : banner.link != null
                    ? () => widget.onOpenLink(banner.link!)
                    : null,
              );
            },
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: FactorySpacing.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < banners.length; i++)
                AnimatedContainer(
                  duration: FactoryMotion.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? colors.primary : colors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
