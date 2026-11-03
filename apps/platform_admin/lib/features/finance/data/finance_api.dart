import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'commission_models.dart';
import 'finance_models.dart';

/// Payouts (`/platform/payouts`) and payments (`/platform/payments`). Reads
/// and reconciliation work for every platform role; payout changes are
/// PLATFORM_ADMIN-only on the backend.
class FinanceApi {
  final Dio _dio;

  FinanceApi(this._dio);

  Future<List<Payout>> payouts({String? status}) async {
    final response = await _dio.get('/platform/payouts', queryParameters: status == null ? null : {'status': status});
    return (response.data as List<dynamic>).map((e) => Payout.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Payout> markProcessing(String payoutId) async {
    final response = await _dio.post('/platform/payouts/$payoutId/mark-processing');
    return Payout.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Payout> markPaid(String payoutId, {String? reference}) async {
    final response = await _dio.post('/platform/payouts/$payoutId/mark-paid', data: {'providerReference': reference});
    return Payout.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Payout> markFailed(String payoutId, {String? reason}) async {
    final response = await _dio.post('/platform/payouts/$payoutId/mark-failed', data: {'reason': reason});
    return Payout.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<FailedRefundPayment>> failedRefunds() async {
    final response = await _dio.get('/platform/payments/failed-refunds');
    return (response.data as List<dynamic>)
        .map((e) => FailedRefundPayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RefundRequest>> refundRequests(String status) async {
    final response = await _dio.get('/platform/payments/refund-requests', queryParameters: {'status': status});
    return (response.data as List<dynamic>).map((e) => RefundRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CommissionSettings> commission() async {
    final response = await _dio.get('/platform/commission');
    return CommissionSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SubscriptionPrice> subscriptionPrice() async {
    final response = await _dio.get('/platform/subscription-price');
    return SubscriptionPrice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SubscriptionPrice> setSubscriptionPrice(num monthlyPrice, String currency) async {
    final response = await _dio.put(
      '/platform/subscription-price',
      data: {'monthlyPrice': monthlyPrice, 'currency': currency},
    );
    return SubscriptionPrice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CommissionSettings> setDefaultCommission(num percent) async {
    final response = await _dio.put('/platform/commission/default', data: {'ratePercent': percent});
    return CommissionSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CommissionSettings> setCategoryCommission(String categoryId, num percent) async {
    final response = await _dio.put('/platform/commission/categories/$categoryId', data: {'ratePercent': percent});
    return CommissionSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CommissionSettings> clearCategoryCommission(String categoryId) async {
    final response = await _dio.delete('/platform/commission/categories/$categoryId');
    return CommissionSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReconciliationResult> reconcile(String paymentId) async {
    final response = await _dio.post('/platform/payments/$paymentId/reconcile');
    return ReconciliationResult.fromJson(response.data as Map<String, dynamic>);
  }
}

final financeApiProvider = Provider<FinanceApi>((ref) => FinanceApi(ref.watch(platformDioProvider)));

/// Payouts of one status, or every payout for `null`.
final payoutsProvider = FutureProvider.autoDispose.family<List<Payout>, String?>(
  (ref, status) => ref.watch(financeApiProvider).payouts(status: status),
);

final failedRefundsProvider = FutureProvider.autoDispose<List<FailedRefundPayment>>(
  (ref) => ref.watch(financeApiProvider).failedRefunds(),
);

final refundRequestsProvider = FutureProvider.autoDispose.family<List<RefundRequest>, String>(
  (ref, status) => ref.watch(financeApiProvider).refundRequests(status),
);

final commissionProvider = FutureProvider.autoDispose<CommissionSettings>(
  (ref) => ref.watch(financeApiProvider).commission(),
);

final subscriptionPriceProvider = FutureProvider.autoDispose<SubscriptionPrice>(
  (ref) => ref.watch(financeApiProvider).subscriptionPrice(),
);
