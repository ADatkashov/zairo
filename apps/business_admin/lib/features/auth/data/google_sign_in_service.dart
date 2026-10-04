import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps `google_sign_in` behind an interface so LoginScreen/tests can
/// substitute a fake instead of driving the real native Google Sign-In UI
/// — same reasoning as AuthApi being non-final. Only ever returns the ID
/// token: the backend is what verifies it
/// (GoogleIdTokenVerifierAdapter) — nothing about the Google account is
/// trusted client-side (see docs/authentication.md).
abstract class GoogleSignInService {
  /// Returns the ID token on success, or null if the user canceled —
  /// canceling is not an error the caller needs to display.
  Future<String?> signIn();

  Future<void> signOut();
}

class DefaultGoogleSignInService implements GoogleSignInService {
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    // Both may be unset in dev/CI (see docs/authentication.md's "Provider
    // configuration" section) — GoogleSignIn.instance.authenticate() then
    // simply fails with a clientConfigurationError, which signIn() below
    // turns into a null (same as a user cancellation) rather than a crash.
    const iosClientId = String.fromEnvironment('GOOGLE_OAUTH_IOS_CLIENT_ID');
    const serverClientId = String.fromEnvironment('GOOGLE_OAUTH_SERVER_CLIENT_ID');
    await GoogleSignIn.instance.initialize(
      clientId: iosClientId.isEmpty ? null : iosClientId,
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _initialized = true;
  }

  @override
  Future<String?> signIn() async {
    await _ensureInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      return null;
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async => GoogleSignIn.instance.signOut();
}

final googleSignInServiceProvider = Provider<GoogleSignInService>((ref) {
  return DefaultGoogleSignInService();
});
