import 'package:core_network/core_network.dart';

import 'models/business_type.dart';
import 'models/catalog_service.dart';
import 'models/category.dart';
import 'models/subsphere.dart';

/// Not final on purpose: tests substitute a subclass overriding
/// [listCategories] instead of hitting the network — same pattern as
/// discovery's DiscoveryApi/favorites' FavoritesApi.
class CatalogApi {
  final DioClient _dioClient;

  CatalogApi(this._dioClient);

  Future<List<Category>> listCategories() async {
    final response = await _dioClient.get('/categories');
    final data = response.data as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The spheres under one category — used for Home's category drill-down,
  /// so a customer can see what a category actually covers before search
  /// (search filtering itself stays keyed on the Category's own `code`, as
  /// it always has — see `_CategoryGrid`'s own doc comment).
  Future<List<BusinessType>> listBusinessTypes(String categoryId) async {
    final response = await _dioClient.get('/categories/$categoryId/business-types');
    final data = response.data as List<dynamic>;
    return data.map((e) => BusinessType.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The optional subspheres under one sphere (empty for most spheres).
  Future<List<Subsphere>> listSubspheres(String businessTypeId) async {
    final response = await _dioClient.get('/business-types/$businessTypeId/subspheres');
    final data = response.data as List<dynamic>;
    return data.map((e) => Subsphere.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// All catalog services of one sphere, including those grouped under a
  /// subsphere (see [CatalogService.subsphereId]) — what a customer can pick
  /// to see "who offers this" (see ServiceCompareScreen).
  Future<List<CatalogService>> listCatalogServices(String businessTypeId) async {
    final response = await _dioClient.get('/business-types/$businessTypeId/services');
    final data = response.data as List<dynamic>;
    return data.map((e) => CatalogService.fromJson(e as Map<String, dynamic>)).toList();
  }
}
