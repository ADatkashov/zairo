import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/auth_exception.dart';
import 'package:business_admin/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every error key maps to its own localized message', () {
    final expected = <AuthErrorKey, String>{
      AuthErrorKey.emailAlreadyRegistered: l10n.errorAuthEmailAlreadyRegistered,
      AuthErrorKey.invalidCredentials: l10n.errorAuthInvalidCredentials,
      AuthErrorKey.invalidResetToken: l10n.errorAuthInvalidResetToken,
      AuthErrorKey.invalidProviderCredential: l10n.errorAuthInvalidProviderCredential,
      AuthErrorKey.invalidPhoneNumber: l10n.errorAuthInvalidPhoneNumber,
      AuthErrorKey.invalidOtp: l10n.errorAuthInvalidOtp,
      AuthErrorKey.otpExpired: l10n.errorAuthOtpExpired,
      AuthErrorKey.tooManyOtpAttempts: l10n.errorAuthTooManyOtpAttempts,
      AuthErrorKey.otpResendCooldown: l10n.errorAuthOtpResendCooldown,
      AuthErrorKey.tooManyOtpRequests: l10n.errorAuthTooManyOtpRequests,
      AuthErrorKey.identityAlreadyLinked: l10n.errorAuthIdentityAlreadyLinked,
      AuthErrorKey.accountLinkRequired: l10n.errorAuthAccountLinkRequired,
      AuthErrorKey.tooManyLoginAttempts: l10n.errorAuthTooManyLoginAttempts,
      AuthErrorKey.phoneCountryNotSupported: l10n.errorAuthPhoneCountryNotSupported,
    };

    expect(expected.keys.toSet(), AuthErrorKey.values.toSet(), reason: 'a new key needs a message here too');
    expected.forEach((key, message) {
      expect(AuthException(key).localizedMessage(l10n), message, reason: key.name);
    });
  });

  test('the messages are all different, so no two failures read the same', () {
    final messages = {for (final key in AuthErrorKey.values) AuthException(key).localizedMessage(l10n)};

    expect(messages, hasLength(AuthErrorKey.values.length));
  });
}
