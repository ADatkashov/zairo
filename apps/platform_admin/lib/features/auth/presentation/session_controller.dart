import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import '../data/auth_api.dart';
import '../data/jwt_expiry.dart';
import '../data/platform_role.dart';
import '../data/platform_session.dart';
import '../data/session_storage.dart';

/// True after the session ended on its own (token expired or was rejected),
/// so the login screen can say why the person is back there. Cleared by the
/// next successful sign-in.
final sessionExpiredProvider = NotifierProvider<SessionExpiredFlag, bool>(SessionExpiredFlag.new);

class SessionExpiredFlag extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// The signed-in staff session, or null. Resolves on startup by trying the
/// stored token (not expired, and accepted by `/auth/me`); the router keeps
/// everyone on the login screen until it resolves to a session.
final sessionControllerProvider = AsyncNotifierProvider<SessionController, PlatformSession?>(SessionController.new);

class SessionController extends AsyncNotifier<PlatformSession?> {
  Timer? _expiryTimer;

  @override
  Future<PlatformSession?> build() async {
    final bus = ref.read(unauthorizedBusProvider)..onUnauthorized = expire;
    ref.onDispose(() {
      _expiryTimer?.cancel();
      bus.onUnauthorized = null;
    });

    final storage = ref.read(sessionStorageProvider);
    // Secure storage can refuse on some desktop setups (no keychain access on
    // macOS, no libsecret on Linux). That must only cost the "stay signed in
    // across restarts" convenience, never stop the console from starting.
    String? token;
    try {
      token = await storage.readToken();
    } catch (_) {
      return null;
    }
    if (token == null) return null;

    final restored = await _tryRestore(token);
    if (restored == null) await _safely(storage.clearToken);
    return restored;
  }

  Future<PlatformSession?> _tryRestore(String token) async {
    final expiresAt = jwtExpiry(token);
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) return null;
    ref.read(authTokenHolderProvider).update(token);
    try {
      final admin = await ref.read(authApiProvider).me();
      return _activate(PlatformSession(accessToken: token, admin: admin, expiresAt: expiresAt));
    } catch (_) {
      ref.read(authTokenHolderProvider).update(null);
      return null;
    }
  }

  /// Throws on failure (wrong password, network) — the login form explains it.
  Future<void> login({required String email, required String password}) async {
    final session = await ref.read(authApiProvider).login(email: email, password: password);
    final storage = ref.read(sessionStorageProvider);
    await _safely(() => storage.saveToken(session.accessToken));
    await _safely(() => storage.saveLastEmail(email));
    ref.read(sessionExpiredProvider.notifier).set(false);
    state = AsyncData(_activate(session));
  }

  PlatformSession _activate(PlatformSession session) {
    ref.read(authTokenHolderProvider).update(session.accessToken);
    _expiryTimer?.cancel();
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final remaining = expiresAt.difference(DateTime.now().toUtc());
      _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, expire);
    }
    return session;
  }

  /// The person chose to leave.
  Future<void> logout() async {
    await _clear();
    ref.read(sessionExpiredProvider.notifier).set(false);
  }

  /// The session ended on its own.
  Future<void> expire() async {
    if (state.value == null) return;
    await _clear();
    ref.read(sessionExpiredProvider.notifier).set(true);
  }

  Future<void> _clear() async {
    _expiryTimer?.cancel();
    ref.read(authTokenHolderProvider).update(null);
    await _safely(ref.read(sessionStorageProvider).clearToken);
    state = const AsyncData(null);
  }

  /// Storage is a convenience: a failure to read or write it is swallowed.
  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  /// Pass null to remove the avatar.
  Future<void> updateAvatar(String? avatarUrl) async {
    final current = state.value;
    if (current == null) return;
    final updated = await ref.read(authApiProvider).updateAvatar(avatarUrl);
    state = AsyncData(
      current.withAdmin(
        current.admin.copyWith(
          displayName: updated.displayName,
          role: updated.role,
          avatarUrl: updated.avatarUrl,
          clearAvatar: updated.avatarUrl == null,
        ),
      ),
    );
  }
}

/// What the signed-in role may do. A signed-out app has no permissions at
/// all — but the router never shows a screen that asks while signed out.
final permissionsProvider = Provider<PlatformPermissions>((ref) {
  return ref.watch(sessionControllerProvider).value?.permissions ?? const PlatformPermissions('');
});
