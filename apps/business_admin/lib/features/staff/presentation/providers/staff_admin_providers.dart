import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/admin_staff.dart';
import '../../data/models/admin_staff_service_summary.dart';
import '../../data/staff_admin_api.dart';

final staffAdminApiProvider = Provider<StaffAdminApi>((ref) {
  return StaffAdminApi(ref.watch(dioClientProvider));
});

/// Keyed by (providerId, includeInactive) — same structural-equality-key
/// pattern as adminMastersProvider/adminCleanersProvider.
final adminStaffProvider =
    FutureProvider.autoDispose.family<List<AdminStaff>, (String providerId, bool includeInactive)>((ref, key) {
  return ref.watch(staffAdminApiProvider).listStaff(key.$1, includeInactive: key.$2);
});

/// "Show removed" toggle for the staff section, per business.
final showInactiveStaffProvider = StateProvider.autoDispose.family<bool, String>((ref, providerId) => false);

final adminStaffServicesProvider =
    FutureProvider.autoDispose.family<List<AdminStaffServiceSummary>, String>((ref, staffId) {
  return ref.watch(staffAdminApiProvider).listStaffServices(staffId);
});
