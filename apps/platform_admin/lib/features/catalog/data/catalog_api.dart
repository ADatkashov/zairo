import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'catalog_models.dart';

/// The master catalog under `/api/v1/platform/**`. Reads are open to every
/// platform role; creating, editing and hiding need PLATFORM_ADMIN. Unlike
/// the public catalog reads, these return every status, so a hidden row stays
/// on screen where it can be switched back on.
class CatalogApi {
  final Dio _dio;

  CatalogApi(this._dio);

  static String _collection(CatalogLevel level) => switch (level) {
    CatalogLevel.category => 'categories',
    CatalogLevel.sphere => 'business-types',
    CatalogLevel.subsphere => 'subspheres',
    CatalogLevel.service => 'services',
  };

  /// [parentId] is the category (for spheres) or the sphere (for subspheres
  /// and services); categories have no parent.
  Future<List<CatalogNode>> list(CatalogLevel level, String? parentId) async {
    final path = switch (level) {
      CatalogLevel.category => '/platform/categories',
      CatalogLevel.sphere => '/platform/categories/$parentId/business-types',
      CatalogLevel.subsphere => '/platform/business-types/$parentId/subspheres',
      CatalogLevel.service => '/platform/business-types/$parentId/services',
    };
    final response = await _dio.get(path);
    return (response.data as List<dynamic>).map((e) => CatalogNode.fromJson(level, e as Map<String, dynamic>)).toList();
  }

  Future<CatalogNode> create(
    CatalogLevel level, {
    String? parentId,
    String? code,
    required String nameKk,
    required String nameRu,
    required String nameEn,
    String? icon,
    required int sortOrder,
    String? subsphereId,
  }) async {
    final data = <String, dynamic>{'nameKk': nameKk, 'nameRu': nameRu, 'nameEn': nameEn, 'sortOrder': sortOrder};
    switch (level) {
      case CatalogLevel.category:
        data
          ..['code'] = code
          ..['icon'] = icon;
      case CatalogLevel.sphere:
        data
          ..['code'] = code
          ..['categoryId'] = parentId;
      case CatalogLevel.subsphere:
        data
          ..['code'] = code
          ..['businessTypeId'] = parentId;
      case CatalogLevel.service:
        data
          ..['businessTypeId'] = parentId
          ..['subsphereId'] = subsphereId;
    }
    final response = await _dio.post('/platform/${_collection(level)}', data: data);
    return CatalogNode.fromJson(level, response.data as Map<String, dynamic>);
  }

  /// Names, position and (for a category) icon. The code and the place in the
  /// tree can't be changed — they are what other data refers to.
  Future<CatalogNode> update(
    CatalogNode node, {
    required String nameKk,
    required String nameRu,
    required String nameEn,
    String? icon,
    required int sortOrder,
  }) async {
    final data = <String, dynamic>{'nameKk': nameKk, 'nameRu': nameRu, 'nameEn': nameEn, 'sortOrder': sortOrder};
    if (node.level == CatalogLevel.category) data['icon'] = icon;
    final response = await _dio.patch('/platform/${_collection(node.level)}/${node.id}', data: data);
    return CatalogNode.fromJson(node.level, response.data as Map<String, dynamic>);
  }

  Future<void> setStatus(CatalogNode node, String status, {String? reason}) async {
    await _dio.patch(
      '/platform/${_collection(node.level)}/${node.id}/status',
      data: {'status': status, 'reason': reason},
    );
  }
}

final catalogApiProvider = Provider<CatalogApi>((ref) => CatalogApi(ref.watch(platformDioProvider)));

/// Rows of one level under one parent.
final catalogNodesProvider = FutureProvider.autoDispose.family<List<CatalogNode>, (CatalogLevel, String?)>(
  (ref, key) => ref.watch(catalogApiProvider).list(key.$1, key.$2),
);
