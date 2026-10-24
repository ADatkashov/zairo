import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'business.dart';

/// `/api/v1/platform/businesses` — readable by every platform role; status
/// changes need PLATFORM_ADMIN or PLATFORM_MODERATOR on the backend.
class BusinessApi {
  final Dio _dio;

  BusinessApi(this._dio);

  Future<List<Business>> list() async {
    final response = await _dio.get('/platform/businesses');
    return (response.data as List<dynamic>).map((e) => Business.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BusinessOverview> overview(String id) async {
    final response = await _dio.get('/platform/businesses/$id/overview');
    return BusinessOverview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setStatus(String id, String status, {String? reason}) async {
    await _dio.patch('/platform/businesses/$id/status', data: {'status': status, 'reason': reason});
  }
}

final businessApiProvider = Provider<BusinessApi>((ref) => BusinessApi(ref.watch(platformDioProvider)));

/// Every business, any status — search and the status filter run on the
/// client, so one list backs the whole screen (and the payout screen's
/// business names).
final businessesProvider = FutureProvider.autoDispose<List<Business>>((ref) => ref.watch(businessApiProvider).list());

/// The moderator's card for one business. A failed load only hides the extra
/// lines; the card still shows what the list already knows.
final businessOverviewProvider = FutureProvider.autoDispose.family<BusinessOverview, String>(
  (ref, id) => ref.watch(businessApiProvider).overview(id),
);
