import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/auth_tokens.dart';

class TokenStorage {
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  // Biometric unlock is a *local gate* in front of the refresh token above: this
  // flag is the only extra state it needs ("should app restart require a
  // successful biometric prompt before restoring the session"). No biometric
  // data is ever stored — see BiometricAuthService.
  static const _biometricEnabledKey = 'auth_biometric_enabled';

  final SecureStorageService _secureStorageService;

  TokenStorage(this._secureStorageService);

  Future<void> save(AuthTokens tokens) async {
    await _secureStorageService.write(_accessTokenKey, tokens.accessToken);
    await _secureStorageService.write(_refreshTokenKey, tokens.refreshToken);
  }

  Future<String?> readAccessToken() => _secureStorageService.read(_accessTokenKey);

  Future<String?> readRefreshToken() => _secureStorageService.read(_refreshTokenKey);

  /// Clears everything, including the biometric-enabled flag — a logout must
  /// not leave a stale "biometric unlock is on" pointing at credentials that no
  /// longer exist.
  Future<void> clear() async {
    await _secureStorageService.delete(_accessTokenKey);
    await _secureStorageService.delete(_refreshTokenKey);
    await _secureStorageService.delete(_biometricEnabledKey);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      await _secureStorageService.write(_biometricEnabledKey, 'true');
    } else {
      await _secureStorageService.delete(_biometricEnabledKey);
    }
  }

  Future<bool> isBiometricEnabled() async {
    return await _secureStorageService.read(_biometricEnabledKey) == 'true';
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(secureStorageServiceProvider));
});
