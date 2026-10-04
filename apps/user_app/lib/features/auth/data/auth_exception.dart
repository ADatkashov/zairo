import '../../../l10n/app_localizations.dart';

/// System messages carry a stable key, not text — see the "Factory Country
/// Architecture" document, section 6/10, and review_exception.dart for the
/// first flow this pattern was proven on. AuthApi (no BuildContext) throws
/// one of these; whichever screen catches it (which does have a context)
/// resolves the actual string via [localizedMessage] at display time.
enum AuthErrorKey {
  emailAlreadyRegistered,
  invalidCredentials,
  invalidResetToken,
  // Multi-provider auth (see IdentityService on the backend — every one of
  // these mirrors one of its named exceptions/status codes).
  invalidProviderCredential,
  invalidPhoneNumber,
  invalidOtp,
  otpExpired,
  tooManyOtpAttempts,
  otpResendCooldown,
  tooManyOtpRequests,
  identityAlreadyLinked,
  accountLinkRequired,
  tooManyLoginAttempts,
}

class AuthException implements Exception {
  final AuthErrorKey key;

  const AuthException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
        AuthErrorKey.emailAlreadyRegistered => l10n.errorAuthEmailAlreadyRegistered,
        AuthErrorKey.invalidCredentials => l10n.errorAuthInvalidCredentials,
        AuthErrorKey.invalidResetToken => l10n.errorAuthInvalidResetToken,
        AuthErrorKey.invalidProviderCredential => l10n.errorAuthInvalidProviderCredential,
        AuthErrorKey.invalidPhoneNumber => l10n.errorAuthInvalidPhoneNumber,
        AuthErrorKey.invalidOtp => l10n.errorAuthInvalidOtp,
        AuthErrorKey.otpExpired => l10n.errorAuthOtpExpired,
        AuthErrorKey.tooManyOtpAttempts => l10n.errorAuthTooManyOtpAttempts,
        AuthErrorKey.otpResendCooldown => l10n.errorAuthOtpResendCooldown,
        AuthErrorKey.tooManyOtpRequests => l10n.errorAuthTooManyOtpRequests,
        AuthErrorKey.identityAlreadyLinked => l10n.errorAuthIdentityAlreadyLinked,
        AuthErrorKey.accountLinkRequired => l10n.errorAuthAccountLinkRequired,
        AuthErrorKey.tooManyLoginAttempts => l10n.errorAuthTooManyLoginAttempts,
      };

  @override
  String toString() => 'AuthException($key)';
}
