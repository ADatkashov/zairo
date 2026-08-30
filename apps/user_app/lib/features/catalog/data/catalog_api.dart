import 'package:core_network/core_network.dart';

import 'models/business_type.dart';
import 'models/category.dart';

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
}
