import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/waitlist_api.dart';

final waitlistApiProvider = Provider<WaitlistApi>((ref) {
  return WaitlistApi(ref.watch(dioClientProvider));
});

/// The ids of the businesses a user is waiting for.
final waitingProviderIdsProvider = FutureProvider.autoDispose.family<Set<String>, String>((ref, userId) {
  return ref.watch(waitlistApiProvider).waitingProviderIds(userId);
});
