import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/city_api.dart';
import '../../data/models/city.dart';

final cityApiProvider = Provider<CityApi>((ref) {
  return CityApi(ref.watch(dioClientProvider));
});

/// Active cities for a country (KZ = Kazakhstan)
final activeCitiesProvider = FutureProvider<List<City>>((ref) async {
  final api = ref.watch(cityApiProvider);
  return api.getActiveCitiesByCountry('KZ');
});
