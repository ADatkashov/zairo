import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_network/core_network.dart';

import '../../data/city_api.dart';
import '../../data/models/city.dart';
import '../../../maps/presentation/providers/maps_providers.dart';

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

/// Nearest city based on user's current location
final nearestCityProvider = FutureProvider<City?>((ref) async {
  final api = ref.watch(cityApiProvider);
  try {
    final location = await ref.watch(currentLocationProvider.future);
    return await api.getNearestCity(location.latitude, location.longitude);
  } catch (e) {
    // If location or geocoding fails, return null
    return null;
  }
});

/// City picked by the user that could not be persisted on the backend
/// (guests have no account to store it on).
class LocalCityOverride extends Notifier<City?> {
  @override
  City? build() => null;

  void set(City? city) => state = city;
}

final localCityOverrideProvider =
    NotifierProvider<LocalCityOverride, City?>(LocalCityOverride.new);

/// Current user's selected city — tries to get from backend first,
/// falls back to nearest city based on location if not set
final userCurrentCityProvider = FutureProvider<City?>((ref) async {
  final api = ref.watch(cityApiProvider);
  // Manual choice made while the backend could not store it (e.g. guest).
  final override = ref.watch(localCityOverrideProvider);
  if (override != null) return override;
  try {
    return await api.getUserCurrentCity();
  } catch (e) {
    // If no city set on backend, use nearest city based on location
    final nearest = await ref.watch(nearestCityProvider.future);
    if (nearest != null) {
      // Auto-select the nearest city
      try {
        return await api.setUserCurrentCity(nearest.code);
      } catch (_) {
        return nearest;
      }
    }
    return null;
  }
});

/// Async notifier for managing city selection
class CitySelectionNotifier extends AsyncNotifier<City?> {
  @override
  Future<City?> build() async {
    return _loadCurrentCity();
  }

  Future<City?> _loadCurrentCity() async {
    final api = ref.watch(cityApiProvider);
    try {
      return await api.getUserCurrentCity();
    } catch (e) {
      return null;
    }
  }

  Future<void> selectCity(String cityCode) async {
    final api = ref.watch(cityApiProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        final city = await api.setUserCurrentCity(cityCode);
        ref.read(localCityOverrideProvider.notifier).set(null);
        return city;
      } catch (_) {
        // Not persisted (guest / offline): keep the choice locally.
        final cities = await ref.read(activeCitiesProvider.future);
        final city = cities.firstWhere((c) => c.code == cityCode);
        ref.read(localCityOverrideProvider.notifier).set(city);
        return city;
      }
    });
  }
}

final citySelectionProvider = AsyncNotifierProvider<CitySelectionNotifier, City?>(
  CitySelectionNotifier.new,
);
