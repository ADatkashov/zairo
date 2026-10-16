import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'ad_banner.dart';

/// `/platform/ads` — read by any platform role, written by PLATFORM_ADMIN or
/// PLATFORM_MODERATOR (the backend decides; the console only offers what the
/// role may do).
class AdApi {
  final Dio _dio;

  AdApi(this._dio);

  Future<List<AdBanner>> list() async {
    final response = await _dio.get('/platform/ads');
    return (response.data as List<dynamic>).map((e) => AdBanner.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [publish] starts the banner live instead of as a draft.
  Future<AdBanner> create({
    required String title,
    String? subtitle,
    required String imageUrl,
    String? videoUrl,
    String? linkTarget,
    String? cityCode,
    required DateTime startsAt,
    required DateTime endsAt,
    required int sortOrder,
    required bool publish,
  }) async {
    final response = await _dio.post(
      '/platform/ads',
      data: _body(title, subtitle, imageUrl, videoUrl, linkTarget, cityCode, startsAt, endsAt, sortOrder)
        ..['status'] = publish ? 'ACTIVE' : 'DRAFT',
    );
    return AdBanner.fromJson(response.data as Map<String, dynamic>);
  }

  /// The backend overwrites every editable field, so the whole banner is sent.
  Future<AdBanner> update(
    String id, {
    required String title,
    String? subtitle,
    required String imageUrl,
    String? videoUrl,
    String? linkTarget,
    String? cityCode,
    required DateTime startsAt,
    required DateTime endsAt,
    required int sortOrder,
  }) async {
    final response = await _dio.put(
      '/platform/ads/$id',
      data: _body(title, subtitle, imageUrl, videoUrl, linkTarget, cityCode, startsAt, endsAt, sortOrder),
    );
    return AdBanner.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdBanner> setStatus(String id, String status, {String? reason}) async {
    final response = await _dio.patch(
      '/platform/ads/$id/status',
      data: {'status': status, 'reason': ?reason},
    );
    return AdBanner.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/platform/ads/$id');
  }

  Map<String, Object?> _body(
    String title,
    String? subtitle,
    String imageUrl,
    String? videoUrl,
    String? linkTarget,
    String? cityCode,
    DateTime startsAt,
    DateTime endsAt,
    int sortOrder,
  ) => {
    'title': title,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'videoUrl': videoUrl,
    'linkTarget': linkTarget,
    'cityCode': cityCode,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'sortOrder': sortOrder,
  };
}

final adApiProvider = Provider<AdApi>((ref) => AdApi(ref.watch(platformDioProvider)));

final adBannersProvider = FutureProvider.autoDispose<List<AdBanner>>((ref) => ref.watch(adApiProvider).list());
