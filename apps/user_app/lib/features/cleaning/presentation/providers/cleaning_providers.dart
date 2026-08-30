import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cleaning_api.dart';
import '../../data/models/cleaner.dart';

final cleaningApiProvider = Provider<CleaningApi>((ref) {
  return CleaningApi(ref.watch(dioClientProvider));
});

final cleanersProvider = FutureProvider.autoDispose.family<List<Cleaner>, String>((ref, providerId) {
  return ref.watch(cleaningApiProvider).listCleaners(providerId);
});
