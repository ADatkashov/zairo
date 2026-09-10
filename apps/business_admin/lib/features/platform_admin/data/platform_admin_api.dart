import 'dart:typed_data';

import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../../storage/data/uploaded_file.dart';
import 'models/platform_admin_account_summary.dart';
import 'models/platform_admin_session.dart';
import 'models/platform_audit_log_entry.dart';

/// Everything under `/api/v1/platform/auth/**`, `/api/v1/platform/admins/**`
/// and `/api/v1/platform/audit-log` — a wholly separate login from the
/// regular business-owner one (`AuthApi`/`authTokenHolderProvider`). See
/// `CatalogApi`'s own doc comment for how the resulting token is used
/// against the catalog admin endpoints.
class PlatformAdminApi {
  final DioClient _dioClient;

  PlatformAdminApi(this._dioClient);

  Future<PlatformAdminSession> login({required String email, required String password}) async {
    final response = await _dioClient.post(
      '/platform/auth/login',
      data: {'email': email, 'password': password},
    );
    return PlatformAdminSession.fromJson(response.data as Map<String, dynamic>);
  }

  /// A platform session doesn't carry a customer/business access token, so
  /// it can't use the regular StorageApi (its uploads go through the
  /// business-owner DioClient interceptor) — this hits the platform-gated
  /// twin, POST /platform/uploads, instead. Pass the returned url straight
  /// into [updateAvatar].
  Future<UploadedFile> uploadAvatar(String platformToken, Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dioClient.post('/platform/uploads', data: formData, options: _authed(platformToken));
    return UploadedFile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Pass null to remove the avatar. [avatarUrl] should come from
  /// [uploadAvatar], not a user-typed URL.
  Future<PlatformAdminAccountSummary> updateAvatar(String platformToken, String? avatarUrl) async {
    final response = await _dioClient.patch(
      '/platform/auth/me/avatar',
      data: {'avatarUrl': avatarUrl},
      options: _authed(platformToken),
    );
    return PlatformAdminAccountSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// PLATFORM_ADMIN-only on the backend — every platform staff account,
  /// active or not.
  Future<List<PlatformAdminAccountSummary>> listAdmins(String platformToken) async {
    final response = await _dioClient.get('/platform/admins', options: _authed(platformToken));
    final data = response.data as List<dynamic>;
    return data.map((e) => PlatformAdminAccountSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// PLATFORM_ADMIN-only on the backend.
  Future<PlatformAdminAccountSummary> createAdmin(
    String platformToken, {
    required String email,
    required String password,
    required String displayName,
    required String role,
    String? reason,
  }) async {
    final response = await _dioClient.post(
      '/platform/admins',
      data: {'email': email, 'password': password, 'displayName': displayName, 'role': role, 'reason': reason},
      options: _authed(platformToken),
    );
    return PlatformAdminAccountSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// PLATFORM_ADMIN-only on the backend, idempotent.
  Future<PlatformAdminAccountSummary> deactivateAdmin(String platformToken, String adminId, {String? reason}) async {
    final response = await _dioClient.post(
      '/platform/admins/$adminId/deactivate',
      data: {'reason': reason},
      options: _authed(platformToken),
    );
    return PlatformAdminAccountSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// PLATFORM_ADMIN-only on the backend, idempotent — undoes deactivateAdmin().
  Future<PlatformAdminAccountSummary> reactivateAdmin(String platformToken, String adminId, {String? reason}) async {
    final response = await _dioClient.post(
      '/platform/admins/$adminId/reactivate',
      data: {'reason': reason},
      options: _authed(platformToken),
    );
    return PlatformAdminAccountSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// Any authenticated platform role can read this — PLATFORM_SUPPORT
  /// included. Newest first; no pagination UI yet (see this feature's own
  /// "deliberately plain, not a polished CMS" doc comment) — just the first
  /// page, large enough to cover normal use.
  Future<List<PlatformAuditLogEntry>> auditLog(String platformToken, {int size = 50}) async {
    final response = await _dioClient.get(
      '/platform/audit-log',
      queryParameters: {'size': size},
      options: _authed(platformToken),
    );
    final content = (response.data as Map<String, dynamic>)['content'] as List<dynamic>;
    return content.map((e) => PlatformAuditLogEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Options _authed(String platformToken) => Options(headers: {'Authorization': 'Bearer $platformToken'});
}
