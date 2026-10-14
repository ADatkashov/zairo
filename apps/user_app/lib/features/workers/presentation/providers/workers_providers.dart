import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/top_worker.dart';
import '../../data/models/worker_profile.dart';
import '../../data/workers_api.dart';

final workersApiProvider = Provider<WorkersApi>((ref) {
  return WorkersApi(ref.watch(dioClientProvider));
});

/// Home's "Best masters" rail. Best-effort by design, like the banners: a rail
/// is never worth an error state on Home, so a failed request is just "no rail".
final topWorkersProvider = FutureProvider.autoDispose<List<TopWorker>>((ref) async {
  try {
    return await ref.watch(workersApiProvider).listTop();
  } catch (_) {
    return const [];
  }
});

final workerProfileProvider = FutureProvider.autoDispose.family<WorkerProfile, String>((ref, workerId) {
  return ref.watch(workersApiProvider).getProfile(workerId);
});
