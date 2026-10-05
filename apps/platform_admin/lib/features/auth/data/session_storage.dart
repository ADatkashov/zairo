import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What survives a restart or a browser refresh: the access token (so a
/// refresh within its 30 minutes doesn't ask for the password again) and the
/// last email typed, as a convenience. The token is dropped on sign-out, on
/// expiry and whenever the backend rejects it.
class SessionStorage {
  static const _tokenKey = 'platform_access_token';
  static const _lastEmailKey = 'platform_last_email';

  final SecureStorageService _storage;

  SessionStorage(this._storage);

  Future<String?> readToken() => _storage.read(_tokenKey);

  Future<void> saveToken(String token) => _storage.write(_tokenKey, token);

  Future<void> clearToken() => _storage.delete(_tokenKey);

  Future<String?> readLastEmail() => _storage.read(_lastEmailKey);

  Future<void> saveLastEmail(String email) => _storage.write(_lastEmailKey, email);
}

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(ref.watch(secureStorageServiceProvider));
});
