import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../salon/data/models/admin_provider.dart';
import '../../data/models/platform_admin_session.dart';
import '../../data/platform_admin_api.dart';
import '../../data/platform_business_api.dart';

final platformAdminApiProvider = Provider<PlatformAdminApi>((ref) {
  return PlatformAdminApi(ref.watch(dioClientProvider));
});

final platformBusinessApiProvider = Provider<PlatformBusinessApi>((ref) {
  return PlatformBusinessApi(ref.watch(dioClientProvider));
});

/// All businesses — the backend returns them unfiltered so this one
/// provider backs the whole Businesses tab (see
/// PlatformAdminTaxonomyScreen's `_BusinessesTab`), which does its own
/// PENDING-first sort rather than needing a separate family provider per
/// status.
final platformBusinessesProvider =
    FutureProvider.autoDispose.family<List<AdminProvider>, String>((ref, platformToken) {
  return ref.watch(platformBusinessApiProvider).list(platformToken);
});

/// In-memory only, on purpose: this is a separate, occasional-use admin
/// tool bolted onto the business-owner app, not a full second app identity
/// — and there's no refresh token to make persisting it worthwhile (see
/// `PlatformAdminSession`'s own doc comment). Logging in again after an app
/// restart is an acceptable cost for how rarely this screen is used.
class PlatformAdminController extends AsyncNotifier<PlatformAdminSession?> {
  @override
  Future<PlatformAdminSession?> build() async => null;

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(platformAdminApiProvider).login(email: email, password: password),
    );
  }

  void logout() {
    state = const AsyncData(null);
  }
}

final platformAdminControllerProvider = AsyncNotifierProvider<PlatformAdminController, PlatformAdminSession?>(
  PlatformAdminController.new,
);
