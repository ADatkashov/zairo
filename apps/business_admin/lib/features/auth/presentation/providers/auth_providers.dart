import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_api.dart';
import '../../data/models/auth_tokens.dart';
import '../../data/models/user_summary.dart';
import '../../data/token_storage.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioClientProvider));
});

/// null = logged out. Same shape/behavior as apps/user_app's AuthController
/// — session restore (access token -> silent refresh -> give up), no
/// per-request 401-retry (same deliberate scope cut, see SESSION_NOTES.md).
class AuthController extends AsyncNotifier<UserSummary?> {
  @override
  Future<UserSummary?> build() async {
    return _restoreSession();
  }

  Future<UserSummary?> _restoreSession() async {
    final api = ref.watch(authApiProvider);
    final storage = ref.watch(tokenStorageProvider);
    final tokenHolder = ref.watch(authTokenHolderProvider);

    final accessToken = await storage.readAccessToken();
    if (accessToken != null) {
      try {
        final user = await api.me(accessToken);
        tokenHolder.update(accessToken);
        return user;
      } catch (_) {
        // Falls through to the refresh attempt below.
      }
    }

    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null) {
      return null;
    }
    try {
      final tokens = await api.refresh(refreshToken);
      await storage.save(tokens);
      tokenHolder.update(tokens.accessToken);
      return tokens.user;
    } catch (_) {
      await storage.clear();
      tokenHolder.update(null);
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref.read(authApiProvider).login(email: email, password: password);
      await _applyTokens(tokens);
      return tokens.user;
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref.read(authApiProvider).register(
            email: email,
            password: password,
            displayName: displayName,
            phone: phone,
          );
      await _applyTokens(tokens);
      return tokens.user;
    });
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    ref.read(authTokenHolderProvider).update(null);
    state = const AsyncValue.data(null);
  }

  /// Pass null to remove the avatar.
  Future<void> updateAvatar(String? avatarUrl) async {
    final updated = await ref.read(authApiProvider).updateAvatar(avatarUrl);
    state = AsyncValue.data(updated);
  }

  Future<void> _applyTokens(AuthTokens tokens) async {
    await ref.read(tokenStorageProvider).save(tokens);
    ref.read(authTokenHolderProvider).update(tokens.accessToken);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, UserSummary?>(AuthController.new);
