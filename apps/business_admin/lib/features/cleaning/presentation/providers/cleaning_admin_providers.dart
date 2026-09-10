import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/cleaning_admin_api.dart';
import '../../data/models/admin_cleaner.dart';
import '../../data/models/admin_cleaner_service_summary.dart';

final cleaningAdminApiProvider = Provider<CleaningAdminApi>((ref) {
  return CleaningAdminApi(ref.watch(dioClientProvider));
});

/// Keyed by (providerId, includeInactive) — same structural-equality-key
/// pattern as adminMastersProvider/adminMechanicsProvider.
final adminCleanersProvider =
    FutureProvider.autoDispose.family<List<AdminCleaner>, (String providerId, bool includeInactive)>((ref, key) {
  return ref.watch(cleaningAdminApiProvider).listCleaners(key.$1, includeInactive: key.$2);
});

/// "Show removed" toggle for the cleaners section, per workshop.
final showInactiveCleanersProvider = StateProvider.autoDispose.family<bool, String>((ref, providerId) => false);

final adminCleanerServicesProvider =
    FutureProvider.autoDispose.family<List<AdminCleanerServiceSummary>, String>((ref, cleanerId) {
  return ref.watch(cleaningAdminApiProvider).listCleanerServices(cleanerId);
});
