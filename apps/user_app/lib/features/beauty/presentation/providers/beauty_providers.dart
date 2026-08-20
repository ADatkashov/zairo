import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/beauty_api.dart';
import '../../data/models/master.dart';
import '../../data/models/portfolio_item.dart';

final beautyApiProvider = Provider<BeautyApi>((ref) {
  return BeautyApi(ref.watch(dioClientProvider));
});

final mastersProvider = FutureProvider.autoDispose.family<List<Master>, String>((ref, providerId) {
  return ref.watch(beautyApiProvider).listMasters(providerId);
});

final masterPortfolioProvider = FutureProvider.autoDispose.family<List<PortfolioItem>, String>((ref, masterId) {
  return ref.watch(beautyApiProvider).listPortfolio(masterId);
});
