import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/beauty_admin_api.dart';
import '../../data/models/admin_master.dart';
import '../../data/models/admin_master_service_summary.dart';
import '../../data/models/admin_portfolio_item.dart';

final beautyAdminApiProvider = Provider<BeautyAdminApi>((ref) {
  return BeautyAdminApi(ref.watch(dioClientProvider));
});

final adminMastersProvider = FutureProvider.autoDispose.family<List<AdminMaster>, String>((ref, providerId) {
  return ref.watch(beautyAdminApiProvider).listMasters(providerId);
});

final adminMasterPortfolioProvider =
    FutureProvider.autoDispose.family<List<AdminPortfolioItem>, String>((ref, masterId) {
  return ref.watch(beautyAdminApiProvider).listPortfolio(masterId);
});

final adminMasterServicesProvider =
    FutureProvider.autoDispose.family<List<AdminMasterServiceSummary>, String>((ref, masterId) {
  return ref.watch(beautyAdminApiProvider).listMasterServices(masterId);
});
