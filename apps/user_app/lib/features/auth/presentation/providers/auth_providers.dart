import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_api.dart';
import '../../data/biometric_auth_service.dart';
import '../../data/facebook_sign_in_service.dart';
import '../../data/google_sign_in_service.dart';
import '../../data/models/auth_tokens.dart';
import '../../data/models/identity_summary.dart';
import '../../data/models/phone_status.dart';
import '../../data/models/user_summary.dart';
import '../../data/token_storage.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioClientProvider));
});

/// null = logged out. AsyncValue's loading/error states cover the rest —
/// no separate hand-rolled state class needed for something this shaped.
class AuthController extends AsyncNotifier<UserSummary?> {
  @override
  Future<UserSummary?> build() async {
    final storage = ref.watch(tokenStorageProvider);
    if (await storage.isBiometricEnabled()) {
      // Gates the already-securely-stored refresh token behind a
      // biometric prompt on every cold start — see
      // docs/authentication.md's "Biometric architecture" section and
      // BiometricAuthService's own doc comment (nothing biometric is ever
      // sent to the backend; this only decides whether *this device*
      // reads what's already stored locally). A declined/failed prompt is
      // treated as logged out for this launch — the person can still log
      // in normally (password/Google/Facebook/phone), or relaunch the app
      // to retry the prompt; it never falls back to skipping the prompt
      // and restoring the session anyway (task spec §17's "biometric
      // bypass").
      final unlocked = await ref
          .watch(biometricAuthServiceProvider)
          .authenticate(reason: 'Unlock ZAIRO');
      if (!unlocked) {
        return null;
      }
    }
    return _restoreSession();
  }

  /// Tries the stored access token, falls back to a silent refresh if that
  /// fails, clears storage if neither works. No per-request 401-retry
  /// beyond this — a deliberate scope cut, see SESSION_NOTES.md. If the
  /// refresh token itself is expired/revoked, this clears storage (which
  /// also turns off biometric unlock — see TokenStorage.clear) rather than
  /// ever minting a new server session from biometric success alone (task
  /// spec §16: "Session expired -> обычный login").
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

  /// [idToken] comes from GoogleSignInService.signIn() — the screen calls
  /// that itself first (it needs to know whether the user canceled before
  /// even calling this), then passes the result here.
  Future<void> loginWithGoogle(String idToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref.read(authApiProvider).loginWithGoogle(idToken);
      await _applyTokens(tokens);
      return tokens.user;
    });
  }

  Future<void> loginWithFacebook(String accessToken) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref.read(authApiProvider).loginWithFacebook(accessToken);
      await _applyTokens(tokens);
      return tokens.user;
    });
  }

  Future<void> requestPhoneOtp(String phone) => ref.read(authApiProvider).requestPhoneOtp(phone);

  Future<void> verifyPhoneOtp({required String phone, required String code}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref.read(authApiProvider).verifyPhoneOtp(phone: phone, code: code);
      await _applyTokens(tokens);
      return tokens.user;
    });
  }

  Future<PhoneStatus> phoneStatus(String phone) => ref.read(authApiProvider).phoneStatus(phone);

  Future<void> loginWithPhonePassword({required String phone, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref.read(authApiProvider).loginWithPhonePassword(phone: phone, password: password);
      await _applyTokens(tokens);
      return tokens.user;
    });
  }

  Future<void> registerWithPhone({
    required String phone,
    required String code,
    required String displayName,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref.read(authApiProvider).registerWithPhone(
            phone: phone,
            code: code,
            displayName: displayName,
            password: password,
          );
      await _applyTokens(tokens);
      return tokens.user;
    });
  }

  /// Throws [AuthException] on a wrong/expired code; the caller then signs
  /// in with the new password (see PhoneOtpPasswordScreen).
  Future<void> resetPasswordWithPhone({
    required String phone,
    required String code,
    required String newPassword,
  }) =>
      ref.read(authApiProvider).resetPasswordWithPhone(phone: phone, code: code, newPassword: newPassword);

  /// Answer to AuthErrorKey.accountLinkRequired — [provider] is 'GOOGLE' or 'FACEBOOK'.
  Future<void> linkProviderWithPassword({
    required String provider,
    required String token,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tokens = await ref
          .read(authApiProvider)
          .linkProviderWithPassword(provider: provider, token: token, password: password);
      await _applyTokens(tokens);
      return tokens.user;
    });
  }

  /// Add-a-login-method flow — the caller must already be authenticated
  /// (see IdentityController.linkGoogle). Keeps the caller's own tokens;
  /// only refreshes the cached UserSummary (e.g. a newly-adopted phone
  /// number/email — see User.adoptPhoneIfMissing on the backend).
  Future<void> linkGoogle(String idToken) async {
    final updated = await ref.read(authApiProvider).linkGoogle(idToken);
    state = AsyncValue.data(updated);
  }

  Future<void> linkFacebook(String accessToken) async {
    final updated = await ref.read(authApiProvider).linkFacebook(accessToken);
    state = AsyncValue.data(updated);
  }

  Future<void> linkPhone({required String phone, required String code}) async {
    final updated = await ref.read(authApiProvider).linkPhone(phone: phone, code: code);
    state = AsyncValue.data(updated);
  }

  Future<List<IdentitySummary>> listIdentities() => ref.read(authApiProvider).listIdentities();

  Future<void> updateProfile({String? displayName, String? email}) async {
    final updated = await ref.read(authApiProvider).updateProfile(displayName: displayName, email: email);
    state = AsyncValue.data(updated);
  }

  Future<bool> isBiometricAvailable() => ref.read(biometricAuthServiceProvider).isAvailable();

  Future<bool> isBiometricEnabled() => ref.read(tokenStorageProvider).isBiometricEnabled();

  /// Prompts once (proves the person enrolled the biometric is actually
  /// present, not just that the hardware exists) before turning the
  /// toggle on — see task spec §14.
  Future<bool> enableBiometric() async {
    final confirmed = await ref
        .read(biometricAuthServiceProvider)
        .authenticate(reason: 'Confirm it\'s you to enable biometric unlock');
    if (!confirmed) return false;
    await ref.read(tokenStorageProvider).setBiometricEnabled(true);
    unawaited(_auditBiometricToggle(true));
    return true;
  }

  Future<void> disableBiometric() async {
    await ref.read(tokenStorageProvider).setBiometricEnabled(false);
    unawaited(_auditBiometricToggle(false));
  }

  Future<void> _auditBiometricToggle(bool enabled) async {
    try {
      await ref.read(authApiProvider).auditBiometricToggle(enabled);
    } catch (_) {
      // Audit-only — never lets a network hiccup undo a local toggle the
      // person already confirmed with their own biometric.
    }
  }

  /// Clears the local session and turns off biometric unlock (see
  /// TokenStorage.clear) — the next launch requires a normal login, not
  /// just a fingerprint (task spec §15: a logout must not leave biometric
  /// as a way around it). Also signs out of the native Google/Facebook SDK
  /// session where applicable, best-effort, so "Continue with Google/
  /// Facebook" prompts an account chooser again next time rather than
  /// silently reusing whichever account was last active.
  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    ref.read(authTokenHolderProvider).update(null);
    unawaited(ref.read(googleSignInServiceProvider).signOut().catchError((_) {}));
    unawaited(ref.read(facebookSignInServiceProvider).signOut().catchError((_) {}));
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
