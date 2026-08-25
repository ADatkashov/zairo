import 'package:core_network/core_network.dart';

import 'models/subscription.dart';

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
}
