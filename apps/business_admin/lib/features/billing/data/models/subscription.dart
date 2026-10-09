/// Mirrors backend's SubscriptionDtos.SubscriptionResponse
/// (backend/subscriptions/.../SubscriptionDtos.java).
class Subscription {
  final String id;
  final String ownerUserId;
  final String plan;
  final String status;
  final PlanLimits limits;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? gracePeriodEndsAt;
  final bool cancelAtPeriodEnd;

  /// Set only by upgrade / retry-charge when the payment provider needs the
  /// owner to pay on its own page. The plan above is still the old one then:
  /// the provider's webhook, not this response, makes the change.
  final String? checkoutUrl;

  /// What PRO costs per month and in which currency, as the server charges it.
  /// Null from an older server: the price row is then left out rather than guessed.
  final double? proMonthlyPrice;
  final String? currency;

  const Subscription({
    required this.id,
    required this.ownerUserId,
    required this.plan,
    required this.status,
    required this.limits,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.gracePeriodEndsAt,
    required this.cancelAtPeriodEnd,
    this.checkoutUrl,
    this.proMonthlyPrice,
    this.currency,
  });

  bool get isPro => plan == 'PRO';

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String,
      plan: json['plan'] as String,
      status: json['status'] as String,
      limits: PlanLimits.fromJson(json['limits'] as Map<String, dynamic>),
      currentPeriodStart: DateTime.parse(json['currentPeriodStart'] as String),
      currentPeriodEnd: DateTime.parse(json['currentPeriodEnd'] as String),
      gracePeriodEndsAt:
          json['gracePeriodEndsAt'] == null ? null : DateTime.parse(json['gracePeriodEndsAt'] as String),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool,
      checkoutUrl: json['checkoutUrl'] as String?,
      proMonthlyPrice: (json['proMonthlyPrice'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
    );
  }
}

class PlanLimits {
  final int maxProviders;
  final int maxStaffPerProvider;

  /// Backend sends Java's Integer.MAX_VALUE for "unlimited" — see [isUnlimitedBookings].
  final int maxBookingsPerMonth;
  final bool recurringScheduleAllowed;

  const PlanLimits({
    required this.maxProviders,
    required this.maxStaffPerProvider,
    required this.maxBookingsPerMonth,
    required this.recurringScheduleAllowed,
  });

  bool get isUnlimitedBookings => maxBookingsPerMonth >= 2147483647;

  factory PlanLimits.fromJson(Map<String, dynamic> json) {
    return PlanLimits(
      maxProviders: json['maxProviders'] as int,
      maxStaffPerProvider: json['maxStaffPerProvider'] as int,
      maxBookingsPerMonth: json['maxBookingsPerMonth'] as int,
      recurringScheduleAllowed: json['recurringScheduleAllowed'] as bool,
    );
  }
}
