import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/ad_banner.dart';

/// Home's promo banners, full-bleed inside the green hero: one banner per page,
/// swipe to change, page dots above the content sheet. It fills whatever box it
/// is given; [topInset] keeps the badges (the "Ad" tag, the play button) clear
/// of the toolbar that sits over the hero, [bottomInset] keeps the text and the
/// dots clear of the sheet's rounded lip.
class HomeHeroBanners extends StatefulWidget {
  const HomeHeroBanners({
    super.key,
    required this.banners,
    required this.onOpenVideo,
    required this.onOpenLink,
    required this.topInset,
    required this.bottomInset,
  });

  final List<AdBanner> banners;

  /// Called for a banner that has a video (the video wins over a link).
  final ValueChanged<AdBanner> onOpenVideo;

  /// Called for a banner without a video that points at a screen of the app; a banner with neither does nothing on tap.
  final ValueChanged<AdLinkTarget> onOpenLink;
  final double topInset;
  final double bottomInset;

  @override
  State<HomeHeroBanners> createState() => _HomeHeroBannersState();
}

class _HomeHeroBannersState extends State<HomeHeroBanners> {
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
    final banners = widget.banners;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
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
              borderRadius: BorderRadius.zero,
              padding: EdgeInsets.fromLTRB(
                FactorySpacing.space4,
                widget.topInset,
                FactorySpacing.space4,
                widget.bottomInset,
              ),
            );
          },
        ),
        // Keeps the white city / icons row readable on a bright cover.
        IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: widget.topInset + FactorySpacing.space4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x73000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        if (banners.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.bottomInset - FactorySpacing.space5,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < banners.length; i++)
                    AnimatedContainer(
                      duration: FactoryMotion.fast,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? Colors.white : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
