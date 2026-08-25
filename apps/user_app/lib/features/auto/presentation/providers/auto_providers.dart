import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auto_api.dart';
import '../../data/models/mechanic.dart';
import '../../data/models/vehicle.dart';

final autoApiProvider = Provider<AutoApi>((ref) {
  return AutoApi(ref.watch(dioClientProvider));
});

final mechanicsProvider = FutureProvider.autoDispose.family<List<Mechanic>, String>((ref, providerId) {
  return ref.watch(autoApiProvider).listMechanics(providerId);
});

final vehiclesProvider = FutureProvider.autoDispose.family<List<Vehicle>, String>((ref, userId) {
  return ref.watch(autoApiProvider).listVehicles(userId);
});
