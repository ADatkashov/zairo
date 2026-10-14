import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/ads/data/ads_api.dart';

import '../../helpers/fake_http.dart';

void main() {
  group('AdsApi', () {
    test('parses banners, with and without a video, and the sponsored flag', () async {
      final http = FakeHttp()
        ..reply('GET', '/ads/banners', [
          {
            'id': 'b1',
            'title': 'AI & Digital Bridge',
            'subtitle': 'Highlights',
            'imageUrl': 'https://cdn.example/1.jpg',
            'videoUrl': 'https://video.example/1',
            'sponsored': true,
          },
          {'id': 'b2', 'title': 'News', 'imageUrl': 'https://cdn.example/2.jpg'},
        ]);

      final banners = await AdsApi(http.client()).listBanners();

      expect(banners, hasLength(2));
      expect(banners[0].title, 'AI & Digital Bridge');
      expect(banners[0].subtitle, 'Highlights');
      expect(banners[0].hasVideo, isTrue);
      expect(banners[0].sponsored, isTrue);
      expect(banners[1].subtitle, isNull);
      expect(banners[1].videoUrl, isNull);
      expect(banners[1].hasVideo, isFalse);
      expect(banners[1].sponsored, isFalse);
    });

    test('sends the city only when there is one', () async {
      final http = FakeHttp()..reply('GET', '/ads/banners', <Object>[]);
      final api = AdsApi(http.client());

      await api.listBanners(cityCode: 'almaty');
      await api.listBanners();
      await api.listBanners(cityCode: '');

      final sent = http.calls('GET', '/ads/banners');
      expect(sent[0].queryParameters, {'city': 'almaty'});
      expect(sent[1].queryParameters, isEmpty);
      expect(sent[2].queryParameters, isEmpty);
    });
  });
}
