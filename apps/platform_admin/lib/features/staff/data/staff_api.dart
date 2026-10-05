import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import '../../auth/data/platform_admin_account.dart';

/// `/api/v1/platform/admins` — PLATFORM_ADMIN-only on the backend.
class StaffApi {
  final Dio _dio;

  StaffApi(this._dio);

  Future<List<PlatformAdminAccount>> list() async {
    final response = await _dio.get('/platform/admins');
    return (response.data as List<dynamic>)
        .map((e) => PlatformAdminAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PlatformAdminAccount> create({
    required String email,
    required String password,
    required String displayName,
    required String role,
    String? reason,
  }) async {
    final response = await _dio.post(
      '/platform/admins',
      data: {'email': email, 'password': password, 'displayName': displayName, 'role': role, 'reason': reason},
    );
    return PlatformAdminAccount.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deactivate(String id, {String? reason}) async {
    await _dio.post('/platform/admins/$id/deactivate', data: {'reason': reason});
  }

  Future<void> reactivate(String id, {String? reason}) async {
    await _dio.post('/platform/admins/$id/reactivate', data: {'reason': reason});
  }
}

final staffApiProvider = Provider<StaffApi>((ref) => StaffApi(ref.watch(platformDioProvider)));

final staffProvider = FutureProvider.autoDispose<List<PlatformAdminAccount>>(
  (ref) => ref.watch(staffApiProvider).list(),
);
