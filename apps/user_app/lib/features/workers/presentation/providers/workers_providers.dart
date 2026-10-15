import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../city/data/models/city.dart';
import '../../../city/presentation/providers/city_providers.dart';
import '../../data/models/top_worker.dart';
import '../../data/models/worker_profile.dart';
import '../../data/workers_api.dart';

final workersApiProvider = Provider<WorkersApi>((ref) {
  return WorkersApi(ref.watch(dioClientProvider));
});

/// Home's "Best masters" rail. Best-effort by design, like the banners: a rail
/// is never worth an error state on Home, so a failed request is just "no rail".
/// Narrowed to the person's city; a city that can't be worked out is not a
/// reason to hide the masters, so it falls back to everywhere.
final topWorkersProvider = FutureProvider.autoDispose<List<TopWorker>>((ref) async {
  final city = await ref.watch(userCurrentCityProvider.future).then<City?>((c) => c, onError: (_) => null);
  try {
    return await ref.watch(workersApiProvider).listTop(cityCode: city?.code);
  } catch (_) {
    return const [];
  }
});

final workerProfileProvider = FutureProvider.autoDispose.family<WorkerProfile, String>((ref, workerId) {
  return ref.watch(workersApiProvider).getProfile(workerId);
});
