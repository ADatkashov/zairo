import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/exceptions.dart';
import 'package:passkeys/types.dart';

/// Wraps the `passkeys` plugin behind an interface so screens/tests can
/// substitute a fake — same reasoning as GoogleSignInService. It only moves
/// WebAuthn JSON between the backend and the platform authenticator; the
/// backend is what verifies the result.
abstract class PasskeyService {
  /// Android 9+/iOS 16+ with a screen lock (and, on Android, a Google account
  /// with a credential provider). Always false on web/desktop.
  Future<bool> isSupported();

  /// Creates a passkey from the backend's WebAuthn creation [options] and
  /// returns the credential JSON to send back; null if the person canceled.
  Future<Map<String, dynamic>?> createCredential(Map<String, dynamic> options);

  /// Signs with a passkey for the backend's WebAuthn request [options] and
  /// returns the credential JSON; null if the person canceled.
  Future<Map<String, dynamic>?> getAssertion(Map<String, dynamic> options);
}

class DefaultPasskeyService implements PasskeyService {
  final PasskeyAuthenticator _authenticator = PasskeyAuthenticator();

  @override
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      // ignore: deprecated_member_use
      return await _authenticator.canAuthenticate();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> createCredential(Map<String, dynamic> options) async {
    try {
      final response = await _authenticator.register(RegisterRequestType.fromJson(options));
      return response.toJson();
    } on PasskeyAuthCancelledException {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> getAssertion(Map<String, dynamic> options) async {
    try {
      final response = await _authenticator.authenticate(
        AuthenticateRequestType.fromJson(
          options,
          mediation: MediationType.Optional,
          preferImmediatelyAvailableCredentials: false,
        ),
      );
      return response.toJson();
    } on PasskeyAuthCancelledException {
      return null;
    }
  }
}

final passkeyServiceProvider = Provider<PasskeyService>((ref) => DefaultPasskeyService());
