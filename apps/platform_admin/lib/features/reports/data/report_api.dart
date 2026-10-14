import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'platform_report.dart';

class ReportApi {
  final Dio _dio;

  ReportApi(this._dio);

  Future<PlatformReport> report(int days) async {
    final response = await _dio.get('/platform/reports', queryParameters: {'days': days});
    return PlatformReport.fromJson(response.data as Map<String, dynamic>);
  }
}

final reportApiProvider = Provider<ReportApi>((ref) => ReportApi(ref.watch(platformDioProvider)));

/// The report for the last `days` days.
final platformReportProvider = FutureProvider.autoDispose.family<PlatformReport, int>(
  (ref, days) => ref.watch(reportApiProvider).report(days),
);
