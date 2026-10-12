import 'package:business_admin/features/loyalty/data/loyalty_admin_exception.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:business_admin/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  String message(int? status, {String? server}) =>
      LoyaltyAdminException(statusCode: status, serverMessage: server).localizedMessage(l10n);

  test('400 shows the server message, or a generic validation message without one', () {
    expect(message(400, server: 'Name is required'), 'Name is required');
    expect(message(400), l10n.errorLoyaltyValidationFailed);
  });

  test('403 and 404 ignore the server text and use the localized messages', () {
    expect(message(403, server: 'raw'), l10n.errorLoyaltyForbidden);
    expect(message(404, server: 'raw'), l10n.errorLoyaltyNotFound);
  });

  test('409 shows the server message, or a generic conflict message without one', () {
    expect(message(409, server: 'Code already used'), 'Code already used');
    expect(message(409), l10n.errorLoyaltyConflict);
  });

  test('any other status shows the server message, or the generic failure', () {
    expect(message(500, server: 'Database down'), 'Database down');
    expect(message(500), l10n.errorLoyaltyActionFailed);
    expect(message(null), l10n.errorLoyaltyActionFailed);
  });

  test('toString names the status and the message for logs', () {
    expect(const LoyaltyAdminException(statusCode: 409, serverMessage: 'x').toString(), contains('409'));
  });
}
