import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/staff.dart';
import '../../data/staff_api.dart';

final staffApiProvider = Provider<StaffApi>((ref) {
  return StaffApi(ref.watch(dioClientProvider));
});

final staffProvider = FutureProvider.autoDispose.family<List<Staff>, String>((
  ref,
  providerId,
) {
  return ref.watch(staffApiProvider).listStaff(providerId);
});
