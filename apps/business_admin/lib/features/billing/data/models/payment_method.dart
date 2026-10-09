/// Mirrors backend's SubscriptionDtos.PaymentMethodResponse: the card the
/// subscription renews with. Brand and last four digits only — the app never
/// sees a full card number.
class PaymentMethod {
  final bool saved;
  final String? brand;
  final String? last4;
  final DateTime? addedAt;

  /// True when the renewal will really be charged by itself; false means the
  /// owner pays each renewal in the provider's checkout.
  final bool autoRenew;

  const PaymentMethod({required this.saved, this.brand, this.last4, this.addedAt, required this.autoRenew});

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      saved: json['saved'] as bool,
      brand: json['brand'] as String?,
      last4: json['last4'] as String?,
      addedAt: json['addedAt'] == null ? null : DateTime.parse(json['addedAt'] as String),
      autoRenew: json['autoRenew'] as bool? ?? false,
    );
  }
}
