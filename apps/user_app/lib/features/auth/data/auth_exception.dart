import '../../../l10n/app_localizations.dart';

/// System messages carry a stable key, not text — see the "Factory Country
/// Architecture" document, section 6/10, and review_exception.dart for the
/// first flow this pattern was proven on. AuthApi (no BuildContext) throws
/// one of these; whichever screen catches it (which does have a context)
/// resolves the actual string via [localizedMessage] at display time.
enum AuthErrorKey {
  emailAlreadyRegistered,
  invalidCredentials,
}

class AuthException implements Exception {
  final AuthErrorKey key;

  const AuthException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
        AuthErrorKey.emailAlreadyRegistered => l10n.errorAuthEmailAlreadyRegistered,
        AuthErrorKey.invalidCredentials => l10n.errorAuthInvalidCredentials,
      };

  @override
  String toString() => 'AuthException($key)';
}
