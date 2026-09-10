import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/beauty_admin_api.dart';
import '../../data/models/admin_master.dart';
import '../../data/models/admin_master_service_summary.dart';
import '../../data/models/admin_portfolio_item.dart';

final beautyAdminApiProvider = Provider<BeautyAdminApi>((ref) {
  return BeautyAdminApi(ref.watch(dioClientProvider));
});

/// Keyed by (providerId, includeInactive) — same structural-equality-key
/// pattern as providerServicesProvider.
final adminMastersProvider =
    FutureProvider.autoDispose.family<List<AdminMaster>, (String providerId, bool includeInactive)>((ref, key) {
  return ref.watch(beautyAdminApiProvider).listMasters(key.$1, includeInactive: key.$2);
});

/// "Show removed" toggle for the masters section, per salon.
final showInactiveMastersProvider = StateProvider.autoDispose.family<bool, String>((ref, providerId) => false);

final adminMasterPortfolioProvider =
    FutureProvider.autoDispose.family<List<AdminPortfolioItem>, String>((ref, masterId) {
  return ref.watch(beautyAdminApiProvider).listPortfolio(masterId);
});

final adminMasterServicesProvider =
    FutureProvider.autoDispose.family<List<AdminMasterServiceSummary>, String>((ref, masterId) {
  return ref.watch(beautyAdminApiProvider).listMasterServices(masterId);
});
