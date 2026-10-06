import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'audit_entry.dart';

class ActivityApi {
  final Dio _dio;

  ActivityApi(this._dio);

  /// Newest first; readable by every platform role.
  Future<List<AuditEntry>> auditLog({required int size}) async {
    final response = await _dio.get('/platform/audit-log', queryParameters: {'size': size});
    final content = (response.data as Map<String, dynamic>)['content'] as List<dynamic>;
    return content.map((e) => AuditEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final activityApiProvider = Provider<ActivityApi>((ref) => ActivityApi(ref.watch(platformDioProvider)));

/// The latest [size] entries (the screen asks for more with "Show more").
final auditLogProvider = FutureProvider.autoDispose.family<List<AuditEntry>, int>(
  (ref, size) => ref.watch(activityApiProvider).auditLog(size: size),
);
