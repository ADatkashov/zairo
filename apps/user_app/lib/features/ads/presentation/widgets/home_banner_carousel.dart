import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/ad_banner.dart';
import '../providers/ads_providers.dart';
import '../screens/ad_video_screen.dart';

/// Home's promo carousel. Draws nothing while loading, on an error, or when
/// there are no live banners — an ad strip never pushes an empty frame or a
/// spinner into the first screen.
class HomeBannerCarousel extends ConsumerWidget {
  const HomeBannerCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(homeBannersProvider).value ?? const <AdBanner>[];
    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      // The gap lives here so Home has no stray spacing when there is no carousel.
      padding: const EdgeInsets.only(top: FactorySpacing.space4),
      child: BannerCarousel(
        banners: banners,
        onOpenVideo: (banner) => context.push(
          AppRoutes.adVideo,
          extra: AdVideoArgs(url: banner.videoUrl!, title: banner.title),
        ),
      ),
    );
  }
}

/// The pager itself, separate from the provider so it can be driven directly.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.banners, required this.onOpenVideo});

  final List<AdBanner> banners;

  /// Called for a banner that has a video; a banner without one does nothing on tap.
  final ValueChanged<AdBanner> onOpenVideo;

  static const height = 176.0;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
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
          height: BannerCarousel.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final banner = banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space1),
                child: FactoryBannerCard(
                  imageUrl: banner.imageUrl,
                  title: banner.title,
                  subtitle: banner.subtitle,
                  tag: banner.sponsored ? l10n.adSponsoredLabel : null,
                  showPlay: banner.hasVideo,
                  playLabel: l10n.adWatchVideoLabel,
                  onTap: banner.hasVideo ? () => widget.onOpenVideo(banner) : null,
                ),
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
                    color: i == _page ? colors.primary : colors.borderStrong,
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
