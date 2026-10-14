import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:zairo/features/ads/data/ads_api.dart';
import 'package:zairo/features/ads/data/models/ad_banner.dart';
import 'package:zairo/features/ads/presentation/providers/ads_providers.dart';
import 'package:zairo/features/ads/presentation/screens/ad_video_screen.dart';
import 'package:zairo/features/ads/presentation/widgets/home_banner_carousel.dart';
import 'package:zairo/features/city/presentation/providers/city_providers.dart';
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

class _FakeAdsApi extends AdsApi {
  _FakeAdsApi(this._banners, {this.fail = false}) : super(DioClient(Dio()));

  final List<AdBanner> _banners;
  final bool fail;

  @override
  Future<List<AdBanner>> listBanners({String? cityCode}) async {
    if (fail) throw Exception('offline');
    return _banners;
  }
}

Future<void> _pump(WidgetTester tester, _FakeAdsApi api, {GoRouter? router}) async {
  final overrides = [
    adsApiProvider.overrideWithValue(api),
    userCurrentCityProvider.overrideWith((ref) async => null),
  ];
  const body = Scaffold(body: SingleChildScrollView(child: HomeBannerCarousel()));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: router == null
          ? MaterialApp(
              theme: factoryLightTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: body,
            )
          : MaterialApp.router(
              theme: factoryLightTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draws nothing when there are no banners, or when the request fails', (tester) async {
    await _pump(tester, _FakeAdsApi(const []));
    expect(find.byType(FactoryBannerCard), findsNothing);
    expect(find.byType(PageView), findsNothing);

    await _pump(tester, _FakeAdsApi(const [_video], fail: true));
    expect(find.byType(FactoryBannerCard), findsNothing);
  });

  testWidgets('shows the banners with the page dots, the Ad label and the play badge', (tester) async {
    await _pump(tester, _FakeAdsApi(const [_video, _sponsored]));

    expect(find.text('AI & Digital Bridge'), findsOneWidget);
    expect(find.text('Watch the highlights'), findsOneWidget);
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);

    // Only the sponsored banner carries the "Ad" label, and it is on the next page.
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Salon promo'), findsOneWidget);
    expect(find.text('Ad'), findsOneWidget);
  });

  testWidgets('one banner has no page dots', (tester) async {
    await _pump(tester, _FakeAdsApi(const [_video]));

    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('several banners show one dot each, the current one wider', (tester) async {
    await _pump(tester, _FakeAdsApi(const [_video, _sponsored]));

    final dots = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
    expect(dots, hasLength(2));
    expect(tester.getSize(find.byWidget(dots[0])).width, greaterThan(tester.getSize(find.byWidget(dots[1])).width));

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    final after = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
    expect(tester.getSize(find.byWidget(after[1])).width, greaterThan(tester.getSize(find.byWidget(after[0])).width));
  });

  testWidgets('tapping a banner with a video opens the player route with its link', (tester) async {
    AdVideoArgs? opened;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: SingleChildScrollView(child: HomeBannerCarousel())),
        ),
        GoRoute(
          path: '/ad-video',
          builder: (_, state) {
            opened = state.extra as AdVideoArgs;
            return const Scaffold(body: Text('Player page'));
          },
        ),
      ],
    );
    await _pump(tester, _FakeAdsApi(const [_video]), router: router);

    await tester.tap(find.text('AI & Digital Bridge'));
    await tester.pumpAndSettle();

    expect(find.text('Player page'), findsOneWidget);
    expect(opened?.url, 'https://video.example/1');
    expect(opened?.title, 'AI & Digital Bridge');
  });

  testWidgets('tapping a banner without a video does nothing', (tester) async {
    final opened = <AdBanner>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BannerCarousel(banners: const [_sponsored], onOpenVideo: opened.add)),
      ),
    );

    await tester.tap(find.text('Salon promo'));
    await tester.pump();

    expect(opened, isEmpty);
  });
}
