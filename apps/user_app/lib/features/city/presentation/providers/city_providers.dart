import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_network/core_network.dart';

import '../../data/city_api.dart';
import '../../data/models/city.dart';

/// CityApi provider
final cityApiProvider = Provider<CityApi>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return CityApi(dioClient);
});

/// Active cities for a country (KZ = Kazakhstan)
final activeCitiesProvider = FutureProvider<List<City>>((ref) async {
  final api = ref.watch(cityApiProvider);
  return api.getActiveCitiesByCountry('KZ');
});

/// Current user's selected city
final userCurrentCityProvider = FutureProvider<City?>((ref) async {
  final api = ref.watch(cityApiProvider);
  try {
    return await api.getUserCurrentCity();
  } catch (e) {
    // User might not have selected a city yet
    return null;
  }
});

/// State notifier for managing city selection
class CitySelectionNotifier extends StateNotifier<AsyncValue<City?>> {
  final CityApi _api;

  CitySelectionNotifier(this._api) : super(const AsyncValue.loading()) {
    _loadCurrentCity();
  }

  Future<void> _loadCurrentCity() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _api.getUserCurrentCity().onError((e, st) => null));
  }

  Future<void> selectCity(String cityCode) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final city = await _api.setUserCurrentCity(cityCode);
      return city;
    });
  }
}

final citySelectionProvider =
    StateNotifierProvider<CitySelectionNotifier, AsyncValue<City?>>((ref) {
  final api = ref.watch(cityApiProvider);
  return CitySelectionNotifier(api);
});
