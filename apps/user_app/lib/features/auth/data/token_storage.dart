import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/auth_tokens.dart';

class TokenStorage {
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  final SecureStorageService _secureStorageService;

  TokenStorage(this._secureStorageService);

  Future<void> save(AuthTokens tokens) async {
    await _secureStorageService.write(_accessTokenKey, tokens.accessToken);
    await _secureStorageService.write(_refreshTokenKey, tokens.refreshToken);
  }

  Future<String?> readAccessToken() => _secureStorageService.read(_accessTokenKey);

  Future<String?> readRefreshToken() => _secureStorageService.read(_refreshTokenKey);

  Future<void> clear() async {
    await _secureStorageService.delete(_accessTokenKey);
    await _secureStorageService.delete(_refreshTokenKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(secureStorageServiceProvider));
});
