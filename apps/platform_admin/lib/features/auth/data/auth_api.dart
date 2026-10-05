import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'platform_admin_account.dart';
import 'platform_session.dart';

/// `/api/v1/platform/auth/**` and `/platform/uploads` — a login wholly
/// separate from the customer / business-owner one.
class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  Future<PlatformSession> login({required String email, required String password}) async {
    final response = await _dio.post(loginPath, data: {'email': email, 'password': password});
    return PlatformSession.fromLoginJson(response.data as Map<String, dynamic>);
  }

  Future<PlatformAdminAccount> me() async {
    final response = await _dio.get('/platform/auth/me');
    return PlatformAdminAccount.fromJson(response.data as Map<String, dynamic>);
  }

  /// Uploads through the platform-gated twin of the regular upload endpoint
  /// and returns the file's URL, ready for [updateAvatar].
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)});
    final response = await _dio.post('/platform/uploads', data: formData);
    return (response.data as Map<String, dynamic>)['url'] as String;
  }

  /// Pass null to remove the avatar.
  Future<PlatformAdminAccount> updateAvatar(String? avatarUrl) async {
    final response = await _dio.patch('/platform/auth/me/avatar', data: {'avatarUrl': avatarUrl});
    return PlatformAdminAccount.fromJson(response.data as Map<String, dynamic>);
  }
}

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(platformDioProvider)));
