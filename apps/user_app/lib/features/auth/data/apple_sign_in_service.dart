import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// What a successful Sign in with Apple gives the app.
class AppleSignInResult {
  /// The identity token (JWT) — the only thing the backend trusts; it is
  /// verified server-side against Apple's published keys.
  final String identityToken;

  /// Apple hands the person's name to the app, never inside the token, and
  /// only on the very first authorization — so it is passed along for use as
  /// the display name when this creates a new account.
  final String? displayName;

  const AppleSignInResult({required this.identityToken, this.displayName});
}

/// Wraps `sign_in_with_apple` behind an interface so screens/tests can
/// substitute a fake — same reasoning as GoogleSignInService.
abstract class AppleSignInService {
  /// Only iOS offers the native flow; elsewhere the Apple button is hidden
  /// (an Android/web flow would need a Services ID and a redirect URL).
  Future<bool> isAvailable();

  /// Null if the person canceled — not an error to display.
  Future<AppleSignInResult?> signIn();
}

class DefaultAppleSignInService implements AppleSignInService {
  @override
  Future<bool> isAvailable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    return SignInWithApple.isAvailable();
  }

  @override
  Future<AppleSignInResult?> signIn() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final token = credential.identityToken;
      if (token == null) return null;
      final name = [credential.givenName, credential.familyName]
          .where((part) => part != null && part.trim().isNotEmpty)
          .join(' ');
      return AppleSignInResult(identityToken: token, displayName: name.isEmpty ? null : name);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }
}

final appleSignInServiceProvider = Provider<AppleSignInService>((ref) => DefaultAppleSignInService());

/// Whether Apple sign-in is switched on for this build
/// (`--dart-define=APPLE_SIGN_IN_ENABLED=false` hides it; see
/// [googleSignInEnabledProvider] for why).
final appleSignInEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('APPLE_SIGN_IN_ENABLED', defaultValue: true),
);

/// Whether to show the Apple button on this device.
final appleSignInAvailableProvider = FutureProvider<bool>((ref) {
  if (!ref.watch(appleSignInEnabledProvider)) return false;
  return ref.watch(appleSignInServiceProvider).isAvailable();
});
