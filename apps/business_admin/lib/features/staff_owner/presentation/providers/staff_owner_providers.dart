import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/needs_attention.dart';
import '../../data/models/reschedule_option.dart';
import '../../data/models/worker_schedule.dart';
import '../../data/staff_owner_api.dart';

final staffOwnerApiProvider = Provider<StaffOwnerApi>((ref) {
  return StaffOwnerApi(ref.watch(dioClientProvider));
});

/// Appointments of one business that need the owner's decision, soonest first.
final needsAttentionProvider = FutureProvider.autoDispose.family<List<NeedsAttentionItem>, String>((ref, providerId) {
  return ref.watch(staffOwnerApiProvider).needsAttention(providerId);
});

/// Everyone who works at the business, with whether they have their own schedule and whether they're off now.
final workersProvider = FutureProvider.autoDispose.family<List<WorkerSummary>, String>((ref, providerId) {
  return ref.watch(staffOwnerApiProvider).workers(providerId);
});

/// One person's rating, star distribution and newest reviews.
final workerRatingProvider =
    FutureProvider.autoDispose.family<WorkerRating, (String providerId, String workerId)>((ref, key) {
  return ref.watch(staffOwnerApiProvider).workerRating(key.$1, key.$2);
});

final workerScheduleProvider =
    FutureProvider.autoDispose.family<WorkerScheduleData, (String providerId, String workerId)>((ref, key) {
  return ref.watch(staffOwnerApiProvider).schedule(key.$1, key.$2);
});

final workerTimeOffProvider =
    FutureProvider.autoDispose.family<List<TimeOffItem>, (String providerId, String workerId)>((ref, key) {
  return ref.watch(staffOwnerApiProvider).timeOff(key.$1, key.$2);
});

final workforceSettingsProvider = FutureProvider.autoDispose.family<WorkforceSettings, String>((ref, providerId) {
  return ref.watch(staffOwnerApiProvider).settings(providerId);
});

final workerPricesProvider =
    FutureProvider.autoDispose.family<Map<String, double>, (String providerId, String workerId)>((ref, key) {
  return ref.watch(staffOwnerApiProvider).workerPrices(key.$1, key.$2);
});

/// The times an appointment can be moved to; read when the owner opens the move sheet.
final ownerRescheduleOptionsProvider = FutureProvider.autoDispose.family<List<RescheduleOption>, String>((ref, bookingId) {
  return ref.watch(staffOwnerApiProvider).rescheduleOptions(bookingId);
});
