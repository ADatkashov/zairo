import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../automation_exception.dart';
import '../models/automation_settings.dart';

/// Wraps the business-admin Automation Center REST surface
/// (backend/automation/.../AutomationSettingsController). `GET` auto-creates
/// an all-enabled/all-default draft on first call, same as
/// [LoyaltyAdminApi.fetchSettings] -- there's always a settings row to show,
/// even before the owner has touched anything. Paths never repeat the
/// `/api/v1` prefix -- [DioClient]'s base URL already includes it.
class AutomationApi {
  final DioClient _dioClient;

  AutomationApi(this._dioClient);

  Future<AutomationSettings> fetchSettings(String providerId) => _run(() async {
        final response = await _dioClient.get('/business/$providerId/automation/settings');
        return AutomationSettings.fromJson(response.data as Map<String, dynamic>);
      });

  Future<AutomationSettings> updateSettings(String providerId, AutomationSettings settings) => _run(() async {
        final response =
            await _dioClient.put('/business/$providerId/automation/settings', data: settings.toUpdateJson());
        return AutomationSettings.fromJson(response.data as Map<String, dynamic>);
      });

  /// Every call funnels through here so a 400/403 always surfaces as an
  /// [AutomationException] carrying the backend's own `message` instead of a
  /// raw DioException.
  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final message = data is Map && data['message'] is String ? data['message'] as String : null;
      throw AutomationException(statusCode: status, serverMessage: message);
    }
  }
}
