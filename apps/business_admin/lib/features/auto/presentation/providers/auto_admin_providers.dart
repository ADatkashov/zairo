import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auto_admin_api.dart';
import '../../data/models/admin_mechanic.dart';
import '../../data/models/admin_mechanic_service_summary.dart';

final autoAdminApiProvider = Provider<AutoAdminApi>((ref) {
  return AutoAdminApi(ref.watch(dioClientProvider));
});

/// Keyed by (providerId, includeInactive) — same structural-equality-key
/// pattern as adminMastersProvider.
final adminMechanicsProvider =
    FutureProvider.autoDispose.family<List<AdminMechanic>, (String providerId, bool includeInactive)>((ref, key) {
  return ref.watch(autoAdminApiProvider).listMechanics(key.$1, includeInactive: key.$2);
});

/// "Show removed" toggle for the mechanics section, per workshop.
final showInactiveMechanicsProvider = StateProvider.autoDispose.family<bool, String>((ref, providerId) => false);

final adminMechanicServicesProvider =
    FutureProvider.autoDispose.family<List<AdminMechanicServiceSummary>, String>((ref, mechanicId) {
  return ref.watch(autoAdminApiProvider).listMechanicServices(mechanicId);
});
