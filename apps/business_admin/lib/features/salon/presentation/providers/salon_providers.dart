import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/admin_booking.dart';
import '../../data/models/admin_provider.dart';
import '../../data/models/admin_service.dart';
import '../../data/models/admin_slot.dart';
import '../../data/models/dashboard_metrics.dart';
import '../../data/salon_admin_api.dart';

final salonAdminApiProvider = Provider<SalonAdminApi>((ref) {
  return SalonAdminApi(ref.watch(dioClientProvider));
});

final myProvidersProvider = FutureProvider.autoDispose.family<List<AdminProvider>, String>((ref, ownerUserId) {
  return ref.watch(salonAdminApiProvider).listMyProviders(ownerUserId);
});

/// Keyed by (providerId, includeInactive) — Dart records give structural
/// equality for free, so this doesn't need a hand-rolled key class.
final providerServicesProvider =
    FutureProvider.autoDispose.family<List<AdminService>, (String providerId, bool includeInactive)>((ref, key) {
  return ref.watch(salonAdminApiProvider).listServices(key.$1, includeInactive: key.$2);
});

/// "Show removed" toggle for the services section, per salon.
final showInactiveServicesProvider = StateProvider.autoDispose.family<bool, String>((ref, providerId) => false);

final providerSlotsProvider = FutureProvider.autoDispose.family<List<AdminSlot>, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).listSlots(providerId);
});

final providerBookingsProvider = FutureProvider.autoDispose.family<List<AdminBooking>, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).listBookings(providerId);
});

final providerDashboardMetricsProvider =
    FutureProvider.autoDispose.family<DashboardMetrics, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).fetchDashboardMetrics(providerId);
});
