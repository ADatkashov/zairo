import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/admin_booking.dart';
import '../../data/models/admin_provider.dart';
import '../../data/models/admin_service.dart';
import '../../data/models/admin_slot.dart';
import '../../data/salon_admin_api.dart';

final salonAdminApiProvider = Provider<SalonAdminApi>((ref) {
  return SalonAdminApi(ref.watch(dioClientProvider));
});

final myProvidersProvider = FutureProvider.autoDispose.family<List<AdminProvider>, String>((ref, ownerUserId) {
  return ref.watch(salonAdminApiProvider).listMyProviders(ownerUserId);
});

final providerServicesProvider = FutureProvider.autoDispose.family<List<AdminService>, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).listServices(providerId);
});

final providerSlotsProvider = FutureProvider.autoDispose.family<List<AdminSlot>, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).listSlots(providerId);
});

final providerBookingsProvider = FutureProvider.autoDispose.family<List<AdminBooking>, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).listBookings(providerId);
});
