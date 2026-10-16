import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'dashboard_metrics.dart';
import 'dashboard_trends.dart';

class DashboardApi {
  final Dio _dio;

  DashboardApi(this._dio);

  Future<DashboardMetrics> metrics() async {
    final response = await _dio.get('/platform/dashboard');
    return DashboardMetrics.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DashboardTrends> trends({int days = DashboardApi.trendDays}) async {
    final response = await _dio.get('/platform/dashboard/trends', queryParameters: {'days': days});
    return DashboardTrends.fromJson(response.data as Map<String, dynamic>);
  }

  static const trendDays = 14;
}

final dashboardApiProvider = Provider<DashboardApi>((ref) => DashboardApi(ref.watch(platformDioProvider)));

final dashboardMetricsProvider = FutureProvider.autoDispose<DashboardMetrics>(
  (ref) => ref.watch(dashboardApiProvider).metrics(),
);

/// Best-effort: the trend lines are decoration on top of the numbers, so a
/// failed or older backend (no such endpoint) yields "no trend" instead of
/// taking the whole dashboard down with it.
final dashboardTrendsProvider = FutureProvider.autoDispose<DashboardTrends>((ref) async {
  try {
    return await ref.watch(dashboardApiProvider).trends();
  } on DioException {
    return const DashboardTrends.empty();
  }
});
