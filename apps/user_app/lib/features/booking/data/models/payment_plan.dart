/// What the backend's payment settings (deposit policy) say a provider
/// charges up front. Mirrors the customer-facing
/// `GET /payment-settings/public` response.
class DepositPolicy {
  final String depositType; // NO_PAYMENT | FULL_PAYMENT | DEPOSIT
  final String? depositValueType; // PERCENTAGE | FIXED_AMOUNT
  final double? depositValue;

  const DepositPolicy({required this.depositType, this.depositValueType, this.depositValue});

  factory DepositPolicy.fromJson(Map<String, dynamic> json) {
    return DepositPolicy(
      depositType: json['depositType'] as String,
      depositValueType: json['depositValueType'] as String?,
      depositValue: (json['depositValue'] as num?)?.toDouble(),
    );
  }
}

enum PaymentMode { free, deposit, full }

/// The three things a customer actually cares about: is it free to book, how
/// much do I pay now, and how much do I pay at the venue.
class PaymentPlan {
  final PaymentMode mode;
  final double total;
  final double dueNow;
  final double atVenue;

  const PaymentPlan._(this.mode, this.total, this.dueNow, this.atVenue);

  /// From the amounts of an existing booking. The venue share is derived
  /// (total - deposit) rather than read from `remainingAmount`, which is the
  /// whole price until the deposit payment lands.
  factory PaymentPlan.fromAmounts({required double total, required double? deposit}) {
    final due = (deposit ?? 0).clamp(0, total).toDouble();
    if (due <= 0) return PaymentPlan._(PaymentMode.free, total, 0, total);
    if (due >= total) return PaymentPlan._(PaymentMode.full, total, total, 0);
    return PaymentPlan._(PaymentMode.deposit, total, due, _round2(total - due));
  }

  /// Mirrors the backend's DepositCalculator so the figure shown before
  /// booking matches the one charged after. An unknown policy reads as
  /// "free", never as a made-up charge.
  factory PaymentPlan.fromPolicy(DepositPolicy? policy, double total) {
    final double deposit;
    switch (policy?.depositType) {
      case 'FULL_PAYMENT':
        deposit = total;
      case 'DEPOSIT':
        final value = policy!.depositValue;
        if (value == null) {
          deposit = 0;
        } else if (policy.depositValueType == 'PERCENTAGE') {
          deposit = _round2(total * value / 100);
        } else if (policy.depositValueType == 'FIXED_AMOUNT') {
          deposit = _round2(value < total ? value : total);
        } else {
          deposit = 0;
        }
      default:
        deposit = 0;
    }
    return PaymentPlan.fromAmounts(total: total, deposit: deposit);
  }

  static double _round2(double v) => (v * 100).round() / 100;
}
