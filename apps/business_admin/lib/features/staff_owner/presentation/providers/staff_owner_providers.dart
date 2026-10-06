import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/needs_attention.dart';
import '../../data/staff_owner_api.dart';

final staffOwnerApiProvider = Provider<StaffOwnerApi>((ref) {
  return StaffOwnerApi(ref.watch(dioClientProvider));
});

/// Appointments of one business that need the owner's decision, soonest first.
final needsAttentionProvider = FutureProvider.autoDispose.family<List<NeedsAttentionItem>, String>((ref, providerId) {
  return ref.watch(staffOwnerApiProvider).needsAttention(providerId);
});
