import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/staff_cabinet_link_api.dart';

final staffCabinetLinkApiProvider = Provider<StaffCabinetLinkApi>((ref) {
  return StaffCabinetLinkApi(ref.watch(dioClientProvider));
});

/// Null while loading, on error, or when the person isn't staff anywhere — the
/// link then simply isn't shown. Otherwise the number of appointments waiting
/// for their acceptance (0 is still "show the link").
final staffCabinetLinkProvider = FutureProvider.autoDispose<int?>((ref) {
  return ref.watch(staffCabinetLinkApiProvider).pendingAppointments();
});
