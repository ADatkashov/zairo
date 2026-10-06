import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../booking/data/models/availability_slot.dart';
import '../../data/change_request_api.dart';
import '../../data/models/any_slot.dart';
import '../../data/models/change_request.dart';
import '../../data/workforce_api.dart';

final workforceApiProvider = Provider<WorkforceApi>((ref) {
  return WorkforceApi(ref.watch(dioClientProvider));
});

/// Whether customers may pick a specific person at this business (the owner's switch). Defaults to yes.
final allowsWorkerChoiceProvider = FutureProvider.autoDispose.family<bool, String>((ref, providerId) {
  return ref.watch(workforceApiProvider).allowsWorkerChoice(providerId);
});

/// One person's bookable times.
final workerSlotsProvider = FutureProvider.autoDispose
    .family<List<AvailabilitySlot>, (String providerId, String workerId)>((ref, key) {
  return ref.watch(workforceApiProvider).workerSlots(key.$1, key.$2);
});

/// Times for "any master" for one service.
final anySlotsProvider = FutureProvider.autoDispose
    .family<List<AnySlot>, (String providerId, String serviceId)>((ref, key) {
  return ref.watch(workforceApiProvider).anySlots(key.$1, key.$2);
});

final changeRequestApiProvider = Provider<ChangeRequestApi>((ref) {
  return ChangeRequestApi(ref.watch(dioClientProvider));
});

/// Appointments where the owner asked the customer to choose a replacement, another time or a refund.
final changeRequestsProvider = FutureProvider.autoDispose<List<ChangeRequest>>((ref) {
  return ref.watch(changeRequestApiProvider).list();
});
