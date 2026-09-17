import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'models/business_type.dart';
import 'models/catalog_service.dart';
import 'models/category.dart';
import 'models/subsphere.dart';

/// Public reads plus PLATFORM_ADMIN-gated mutations of the master catalog.
/// The mutation endpoints (`/api/v1/platform/**`) take a *platform* access
/// token, not the regular business-owner one `DioClient`'s interceptor
/// attaches automatically — every mutation method here takes that token
/// explicitly and passes it as an `Options` header, overriding whatever the
/// interceptor would have set (see `PlatformAdminApi`/`PlatformAdminAuth`
/// for how that token is obtained; it's a wholly separate login).
class CatalogApi {
  final DioClient _dioClient;

  CatalogApi(this._dioClient);

  Future<List<Category>> listCategories() async {
    final response = await _dioClient.get('/categories');
    final data = response.data as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BusinessType>> listBusinessTypes(String categoryId) async {
    final response = await _dioClient.get('/categories/$categoryId/business-types');
    final data = response.data as List<dynamic>;
    return data.map((e) => BusinessType.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Subsphere>> listSubspheres(String businessTypeId) async {
    final response = await _dioClient.get('/business-types/$businessTypeId/subspheres');
    final data = response.data as List<dynamic>;
    return data.map((e) => Subsphere.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CatalogServiceModel>> listServicesByBusinessType(String businessTypeId) async {
    final response = await _dioClient.get('/business-types/$businessTypeId/services');
    final data = response.data as List<dynamic>;
    return data.map((e) => CatalogServiceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---- Admin reads (any status, not just ACTIVE) -------------------
  //
  // The Platform Admin taxonomy screen's own list: the public reads above
  // are ACTIVE-only by design (see backend's CatalogController doc
  // comment), which meant deactivating a category made it vanish from the
  // very screen that could reactivate it. These hit the admin-only
  // `/platform/**` GETs instead, so INACTIVE/ARCHIVED entries stay visible
  // (with a status toggle) here.

  Future<List<Category>> listAllCategories(String platformToken) async {
    final response = await _dioClient.get('/platform/categories', options: _authed(platformToken));
    final data = response.data as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BusinessType>> listAllBusinessTypes(String platformToken, String categoryId) async {
    final response = await _dioClient.get(
      '/platform/categories/$categoryId/business-types',
      options: _authed(platformToken),
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => BusinessType.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Subsphere>> listAllSubspheres(String platformToken, String businessTypeId) async {
    final response = await _dioClient.get(
      '/platform/business-types/$businessTypeId/subspheres',
      options: _authed(platformToken),
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => Subsphere.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CatalogServiceModel>> listAllCatalogServices(String platformToken, String businessTypeId) async {
    final response = await _dioClient.get(
      '/platform/business-types/$businessTypeId/services',
      options: _authed(platformToken),
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => CatalogServiceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Category> createCategory(
    String platformToken, {
    required String code,
    required String nameKk,
    required String nameRu,
    required String nameEn,
    String? icon,
    required int sortOrder,
  }) async {
    final response = await _dioClient.post(
      '/platform/categories',
      data: {'code': code, 'nameKk': nameKk, 'nameRu': nameRu, 'nameEn': nameEn, 'icon': icon, 'sortOrder': sortOrder},
      options: _authed(platformToken),
    );
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setCategoryStatus(String platformToken, String id, String status) =>
      _setStatus(platformToken, '/platform/categories/$id/status', status);

  Future<BusinessType> createBusinessType(
    String platformToken, {
    required String categoryId,
    required String code,
    required String nameKk,
    required String nameRu,
    required String nameEn,
    required int sortOrder,
  }) async {
    final response = await _dioClient.post(
      '/platform/business-types',
      data: {
        'categoryId': categoryId,
        'code': code,
        'nameKk': nameKk,
        'nameRu': nameRu,
        'nameEn': nameEn,
        'sortOrder': sortOrder,
      },
      options: _authed(platformToken),
    );
    return BusinessType.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setBusinessTypeStatus(String platformToken, String id, String status) =>
      _setStatus(platformToken, '/platform/business-types/$id/status', status);

  Future<Subsphere> createSubsphere(
    String platformToken, {
    required String businessTypeId,
    required String code,
    required String nameKk,
    required String nameRu,
    required String nameEn,
    required int sortOrder,
  }) async {
    final response = await _dioClient.post(
      '/platform/subspheres',
      data: {
        'businessTypeId': businessTypeId,
        'code': code,
        'nameKk': nameKk,
        'nameRu': nameRu,
        'nameEn': nameEn,
        'sortOrder': sortOrder,
      },
      options: _authed(platformToken),
    );
    return Subsphere.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setSubsphereStatus(String platformToken, String id, String status) =>
      _setStatus(platformToken, '/platform/subspheres/$id/status', status);

  Future<CatalogServiceModel> createCatalogService(
    String platformToken, {
    required String businessTypeId,
    String? subsphereId,
    required String nameKk,
    required String nameRu,
    required String nameEn,
    required int sortOrder,
  }) async {
    final response = await _dioClient.post(
      '/platform/services',
      data: {
        'businessTypeId': businessTypeId,
        'subsphereId': subsphereId,
        'nameKk': nameKk,
        'nameRu': nameRu,
        'nameEn': nameEn,
        'sortOrder': sortOrder,
      },
      options: _authed(platformToken),
    );
    return CatalogServiceModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setCatalogServiceStatus(String platformToken, String id, String status) =>
      _setStatus(platformToken, '/platform/services/$id/status', status);

  Future<void> _setStatus(String platformToken, String path, String status) async {
    await _dioClient.patch(path, data: {'status': status}, options: _authed(platformToken));
  }

  Options _authed(String platformToken) => Options(headers: {'Authorization': 'Bearer $platformToken'});
}
