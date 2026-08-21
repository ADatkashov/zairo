import '../../../l10n/app_localizations.dart';

enum PaymentErrorKey {
  alreadyPaid,
}

class PaymentException implements Exception {
  final PaymentErrorKey key;

  const PaymentException(this.key);

  String localizedMessage(AppLocalizations l10n) => switch (key) {
        PaymentErrorKey.alreadyPaid => l10n.errorPaymentAlreadyPaid,
      };

  @override
  String toString() => 'PaymentException($key)';
}
