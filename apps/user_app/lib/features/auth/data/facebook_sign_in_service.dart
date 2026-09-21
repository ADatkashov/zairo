import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps `flutter_facebook_auth` behind an interface — same reasoning as
/// GoogleSignInService. Only ever returns the access token: the backend
/// verifies it against the Graph API's debug_token endpoint
/// (FacebookGraphIdentityVerifier) before trusting anything about the
/// account (see docs/authentication.md).
abstract class FacebookSignInService {
  /// Returns the access token on success, or null if the user canceled or
  /// the login otherwise failed (e.g. Facebook isn't configured — see
  /// docs/authentication.md's "Provider configuration" section) — neither
  /// is an error the caller needs to display as a failure banner.
  Future<String?> signIn();

  Future<void> signOut();
}

class DefaultFacebookSignInService implements FacebookSignInService {
  @override
  Future<String?> signIn() async {
    final result = await FacebookAuth.instance.login(permissions: const ['email', 'public_profile']);
    if (result.status != LoginStatus.success) {
      return null;
    }
    return result.accessToken?.tokenString;
  }

  @override
  Future<void> signOut() => FacebookAuth.instance.logOut();
}

final facebookSignInServiceProvider = Provider<FacebookSignInService>((ref) {
  return DefaultFacebookSignInService();
});
