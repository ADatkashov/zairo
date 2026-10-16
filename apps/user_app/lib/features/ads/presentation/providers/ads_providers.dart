import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../city/data/models/city.dart';
import '../../../city/presentation/providers/city_providers.dart';
import '../../data/ads_api.dart';
import '../../data/models/ad_banner.dart';

final adsApiProvider = Provider<AdsApi>((ref) {
  return AdsApi(ref.watch(dioClientProvider));
});

/// The Home carousel for the user's city. Best-effort by design: an ad strip
/// is never worth an error state on Home, so a failed request (or no city
/// yet) is just "no banners" and Home draws nothing in its place.
final homeBannersProvider = FutureProvider.autoDispose<List<AdBanner>>((ref) async {
  // A city that can't be worked out is not a reason to hide the banners meant
  // for everyone.
  final city = await ref.watch(userCurrentCityProvider.future).then<City?>((c) => c, onError: (_) => null);
  try {
    return await ref.watch(adsApiProvider).listBanners(cityCode: city?.code);
  } catch (_) {
    return const [];
  }
});
