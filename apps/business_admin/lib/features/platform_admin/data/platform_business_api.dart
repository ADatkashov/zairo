import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../salon/data/models/admin_provider.dart';

/// Business moderation from the Control Center — `/api/v1/platform/businesses`,
/// PLATFORM_ADMIN/PLATFORM_MODERATOR gated on the backend (see
/// ProviderAdminController). Same `Provider` resource and `AdminProvider`
/// model the legacy ADMIN-role ModerationScreen already uses (see
/// SalonAdminApi) — just reachable with a platform token instead of that
/// separate login, so a platform moderator never has to touch the database
/// to approve or suspend a business.
class PlatformBusinessApi {
  final DioClient _dioClient;

  PlatformBusinessApi(this._dioClient);

  Future<List<AdminProvider>> list(String platformToken, {String? status}) async {
    final response = await _dioClient.get(
      '/platform/businesses',
      queryParameters: status == null ? null : {'status': status},
      options: _authed(platformToken),
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => AdminProvider.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setStatus(String platformToken, String id, String status, {String? reason}) async {
    await _dioClient.patch(
      '/platform/businesses/$id/status',
      data: {'status': status, 'reason': reason},
      options: _authed(platformToken),
    );
  }

  Options _authed(String platformToken) => Options(headers: {'Authorization': 'Bearer $platformToken'});
}
