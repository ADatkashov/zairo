import '../../../l10n/app_localizations.dart';

enum AuthErrorKey {
  emailAlreadyRegistered,
  invalidCredentials,
  invalidResetToken,
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
  phoneCountryNotSupported,
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
        AuthErrorKey.phoneCountryNotSupported => l10n.errorAuthPhoneCountryNotSupported,
      };

  @override
  String toString() => 'AuthException($key)';
}
