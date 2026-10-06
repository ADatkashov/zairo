import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/staff_cabinet.dart';
import '../../data/staff_cabinet_api.dart';

final staffCabinetApiProvider = Provider<StaffCabinetApi>((ref) {
  return StaffCabinetApi(ref.watch(dioClientProvider));
});

/// Every business the signed-in user works at. Empty for anyone who isn't
/// staff — the Profile screen uses that to decide whether to show the cabinet.
final staffMembershipsProvider = FutureProvider.autoDispose<List<StaffMembership>>((ref) {
  return ref.watch(staffCabinetApiProvider).memberships();
});

final staffAppointmentsProvider =
    FutureProvider.autoDispose.family<List<StaffAppointment>, String>((ref, staffId) {
  return ref.watch(staffCabinetApiProvider).appointments(staffId);
});

final staffRatingProvider = FutureProvider.autoDispose.family<StaffRating, String>((ref, staffId) {
  return ref.watch(staffCabinetApiProvider).rating(staffId);
});
