import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps `local_auth` behind an interface — see docs/authentication.md's
/// "Biometric architecture" section. Deliberately the *only* thing in this
/// feature that talks to platform biometric APIs: it never receives, sends,
/// or stores a fingerprint/face template/image — [authenticate] returns a
/// plain yes/no from the OS, which is the platform's own Keystore/Secure-
/// Enclave-backed guarantee that the enrolled person is present, not
/// biometric data ZAIRO could mishandle even if it wanted to (see task spec
/// §12: "Биометрия НЕ является credential, которую нужно отправлять на
/// backend").
abstract class BiometricAuthService {
  /// True only when the device has usable biometric hardware *and* at
  /// least one biometric is actually enrolled — see task spec §14's
  /// "graceful fallback": a toggle for an unusable method must not even
  /// render as available.
  Future<bool> isAvailable();

  /// Shows the platform's own biometric prompt. Returns false on any
  /// failure/cancellation/lockout — never throws for a declined prompt,
  /// only for a genuinely unexpected platform error.
  Future<bool> authenticate({required String reason});
}

class DefaultBiometricAuthService implements BiometricAuthService {
  final LocalAuthentication _localAuth;

  DefaultBiometricAuthService([LocalAuthentication? localAuth]) : _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !deviceSupported) {
        return false;
      }
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        // Biometric hardware only — a device PIN/pattern fallback would
        // let anyone who knows the phone's lock code (not necessarily the
        // account owner) unlock the session, which defeats the point of
        // offering this as a *stronger* option than just staying logged
        // in. See task spec §14/§17's "biometric bypass" threat.
        biometricOnly: true,
        // Keeps the prompt alive through the brief inactive/paused
        // lifecycle blips of a cold start; otherwise local_auth cancels it
        // and the person is bounced to the login screen.
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      return false;
    }
  }
}

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return DefaultBiometricAuthService();
});
