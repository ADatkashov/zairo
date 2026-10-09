import 'package:core_network/core_network.dart';

import 'models/payment_method.dart';
import 'models/subscription.dart';
import 'models/subscription_charge.dart';

/// Wraps backend's subscriptions module (backend/subscriptions/.../SubscriptionController.java)
/// — the owner's own tariff plan, usage limits, and upgrade/downgrade.
class BillingApi {
  final DioClient _dioClient;

  BillingApi(this._dioClient);

  Future<Subscription> getMine() async {
    final response = await _dioClient.get('/subscriptions/me');
    return Subscription.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Subscription> upgradeToPro() async {
    final response = await _dioClient.post('/subscriptions/upgrade');
    return Subscription.fromJson(response.data as Map<String, dynamic>);
  }

  /// Self-service, takes effect at the end of the current paid period — see
  /// backend's SubscriptionController.downgrade() doc comment.
  Future<Subscription> downgradeToFree() async {
    final response = await _dioClient.post('/subscriptions/downgrade');
    return Subscription.fromJson(response.data as Map<String, dynamic>);
  }

  /// The Billing screen's grace-period banner's "Fix" button — only valid
  /// while [Subscription.status] is PAST_DUE (409 otherwise). When the
  /// provider can't charge the stored card by itself, the result carries a
  /// [Subscription.checkoutUrl] to pay on instead.
  Future<Subscription> retryPastDueCharge() async {
    final response = await _dioClient.post('/subscriptions/retry-charge');
    return Subscription.fromJson(response.data as Map<String, dynamic>);
  }

  /// The card the subscription renews with ([PaymentMethod.saved] false when none).
  Future<PaymentMethod> getPaymentMethod() async {
    final response = await _dioClient.get('/subscriptions/me/payment-method');
    return PaymentMethod.fromJson(response.data as Map<String, dynamic>);
  }

  /// Forgets the stored card on the server (idempotent).
  Future<void> removePaymentMethod() async {
    await _dioClient.delete('/subscriptions/me/payment-method');
  }

  /// The Billing screen's invoice history — most recent charge first.
  Future<List<SubscriptionCharge>> listCharges() async {
    final response = await _dioClient.get('/subscriptions/me/charges');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => SubscriptionCharge.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
