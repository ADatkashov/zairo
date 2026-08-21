import '../../../l10n/app_localizations.dart';

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
