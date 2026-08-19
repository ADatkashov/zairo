import 'package:flutter_riverpod/flutter_riverpod.dart';

/// core_network doesn't know anything about login/registration — the auth
/// feature (in the app, not in this package) pushes the current access
/// token here whenever it changes (login/refresh/logout), and dioProvider
/// reads it synchronously to attach the Authorization header. This is the
/// same "app overrides, Core stays ignorant" pattern as [NetworkConfig].
class AuthTokenHolder {
  String? _accessToken;

  String? get accessToken => _accessToken;

  void update(String? accessToken) {
    _accessToken = accessToken;
  }
}

final authTokenHolderProvider = Provider<AuthTokenHolder>((ref) {
  return AuthTokenHolder();
});
