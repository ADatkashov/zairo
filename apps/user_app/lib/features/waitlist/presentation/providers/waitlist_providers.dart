import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/waitlist_entry.dart';
import '../../data/waitlist_api.dart';

final waitlistApiProvider = Provider<WaitlistApi>((ref) {
  return WaitlistApi(ref.watch(dioClientProvider));
});

/// The businesses a user is waiting for, by business id.
final waitlistEntriesProvider = FutureProvider.autoDispose.family<Map<String, WaitlistEntry>, String>((ref, userId) {
  return ref.watch(waitlistApiProvider).listEntries(userId);
});
