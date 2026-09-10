import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/storage_api.dart';

final storageApiProvider = Provider<StorageApi>((ref) {
  return StorageApi(ref.watch(dioClientProvider));
});
