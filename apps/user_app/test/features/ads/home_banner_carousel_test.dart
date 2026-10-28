import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:zairo/features/ads/data/models/ad_banner.dart';
import 'package:zairo/features/ads/presentation/widgets/home_banner_carousel.dart';
import 'package:zairo/l10n/app_localizations.dart';

const _video = AdBanner(
  id: 'b1',
  title: 'AI & Digital Bridge',
  subtitle: 'Watch the highlights',
  imageUrl: 'https://cdn.example/1.jpg',
  videoUrl: 'https://video.example/1',
  sponsored: false,
);
const _sponsored = AdBanner(
  id: 'b2',
  title: 'Salon promo',
  subtitle: null,
  imageUrl: 'https://cdn.example/2.jpg',
  videoUrl: null,
  sponsored: true,
);

Future<void> _pump(
  WidgetTester tester,
  List<AdBanner> banners, {
  ValueChanged<AdBanner>? onOpenVideo,
  ValueChanged<AdLinkTarget>? onOpenLink,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: HomeBannerCarousel(
            banners: banners,
            onOpenVideo: onOpenVideo ?? (_) {},
            onOpenLink: onOpenLink ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('is a rounded card of a fixed height inside the page padding, not a full-bleed hero', (tester) async {
    await _pump(tester, const [_video]);

    expect(tester.getSize(find.byType(FactoryBannerCard)).height, HomeBannerCarousel.height);
    expect(tester.getSize(find.byType(FactoryBannerCard)).width, 800 - 32);
    final clip = tester.widget<ClipRRect>(find.descendant(of: find.byType(FactoryBannerCard), matching: find.byType(ClipRRect)));
    expect(clip.borderRadius, isNot(BorderRadius.zero));
  });

  testWidgets('shows title, subtitle and the play badge', (tester) async {
    await _pump(tester, const [_video]);

    expect(find.text('AI & Digital Bridge'), findsOneWidget);
    expect(find.text('Watch the highlights'), findsOneWidget);
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('swiping shows the next banner; only a sponsored one carries the Ad label', (tester) async {
    await _pump(tester, const [_video, _sponsored]);
    expect(find.text('Ad'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Salon promo'), findsOneWidget);
    expect(find.text('Ad'), findsOneWidget);
  });

  testWidgets('one banner has no page dots; several have one each, the current one wider', (tester) async {
    await _pump(tester, const [_video]);
    expect(find.byType(AnimatedContainer), findsNothing);

    await _pump(tester, const [_video, _sponsored]);
    var dots = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
    expect(dots, hasLength(2));
    expect(tester.getSize(find.byWidget(dots[0])).width, greaterThan(tester.getSize(find.byWidget(dots[1])).width));

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    dots = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
    expect(tester.getSize(find.byWidget(dots[1])).width, greaterThan(tester.getSize(find.byWidget(dots[0])).width));
  });

  testWidgets('tapping a banner with a video reports it; one without does nothing', (tester) async {
    final opened = <AdBanner>[];
    await _pump(tester, const [_video, _sponsored], onOpenVideo: opened.add);

    await tester.tap(find.text('AI & Digital Bridge'));
    await tester.pump();
    expect(opened, [_video]);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salon promo'));
    await tester.pump();
    expect(opened, [_video]);
  });

  testWidgets('tapping a banner without a video that has a link reports where it points', (tester) async {
    const rewards = AdBanner(
      id: 'b3',
      title: 'Earn bonuses',
      subtitle: null,
      imageUrl: 'https://cdn.example/3.jpg',
      videoUrl: null,
      linkTarget: 'REWARDS',
      sponsored: false,
    );
    final opened = <AdLinkTarget>[];
    await _pump(tester, const [rewards], onOpenLink: opened.add);

    await tester.tap(find.text('Earn bonuses'));
    await tester.pump();

    expect(opened, [AdLinkTarget.rewards]);
  });

  testWidgets('a video wins over a link: the video opens, the link does not', (tester) async {
    const both = AdBanner(
      id: 'b4',
      title: 'Watch and earn',
      subtitle: null,
      imageUrl: 'https://cdn.example/4.jpg',
      videoUrl: 'https://video.example/4',
      linkTarget: 'SEARCH',
      sponsored: false,
    );
    final videos = <AdBanner>[];
    final links = <AdLinkTarget>[];
    await _pump(tester, const [both], onOpenVideo: videos.add, onOpenLink: links.add);

    await tester.tap(find.text('Watch and earn'));
    await tester.pump();

    expect(videos, [both]);
    expect(links, isEmpty);
  });

  test('link targets map to screens; an unknown one opens nothing', () {
    AdBanner of(String? target) => AdBanner(
      id: 'x',
      title: 't',
      subtitle: null,
      imageUrl: 'https://cdn.example/x.jpg',
      videoUrl: null,
      linkTarget: target,
      sponsored: false,
    );

    expect(of('REWARDS').link, AdLinkTarget.rewards);
    expect(of('SEARCH').link, AdLinkTarget.search);
    expect(of('SOMETHING_NEW').link, isNull);
    expect(of(null).link, isNull);
    expect(AdBanner.fromJson({'id': 'x', 'title': 't', 'imageUrl': 'https://c/x.jpg', 'linkTarget': 'SEARCH'}).link,
        AdLinkTarget.search);
  });
}
