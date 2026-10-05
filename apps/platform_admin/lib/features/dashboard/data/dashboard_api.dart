import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'dashboard_metrics.dart';

class DashboardApi {
  final Dio _dio;

  DashboardApi(this._dio);

  Future<DashboardMetrics> metrics() async {
    final response = await _dio.get('/platform/dashboard');
    return DashboardMetrics.fromJson(response.data as Map<String, dynamic>);
  }
}

final dashboardApiProvider = Provider<DashboardApi>((ref) => DashboardApi(ref.watch(platformDioProvider)));

final dashboardMetricsProvider = FutureProvider.autoDispose<DashboardMetrics>(
  (ref) => ref.watch(dashboardApiProvider).metrics(),
);
