import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../salon/data/models/admin_provider.dart';
import '../../data/models/platform_admin_account_summary.dart';
import '../../data/models/platform_admin_session.dart';
import '../../data/models/platform_audit_log_entry.dart';
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
/// PlatformAdminBusinessesTab), which does its own
/// PENDING-first sort rather than needing a separate family provider per
/// status.
final platformBusinessesProvider =
    FutureProvider.autoDispose.family<List<AdminProvider>, String>((ref, platformToken) {
  return ref.watch(platformBusinessApiProvider).list(platformToken);
});

/// The Staff tab's list — PLATFORM_ADMIN-only on the backend (a
/// PLATFORM_SUPPORT/MODERATOR session simply never reaches this, since the
/// tab itself is hidden for them — see PlatformAdminConsoleScreen).
final platformAdminsProvider = FutureProvider.autoDispose.family<List<PlatformAdminAccountSummary>, String>(
  (ref, platformToken) => ref.watch(platformAdminApiProvider).listAdmins(platformToken),
);

/// The Audit Log tab's list — any authenticated platform role can read this.
final platformAuditLogProvider = FutureProvider.autoDispose.family<List<PlatformAuditLogEntry>, String>(
  (ref, platformToken) => ref.watch(platformAdminApiProvider).auditLog(platformToken),
);

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

  /// Pass null to remove the avatar.
  Future<void> updateAvatar(String? avatarUrl) async {
    final current = state.value;
    if (current == null) return;
    final updated = await ref.read(platformAdminApiProvider).updateAvatar(current.accessToken, avatarUrl);
    state = AsyncData(
      current.copyWithAdmin(displayName: updated.displayName, role: updated.role, avatarUrl: updated.avatarUrl),
    );
  }
}

final platformAdminControllerProvider = AsyncNotifierProvider<PlatformAdminController, PlatformAdminSession?>(
  PlatformAdminController.new,
);
