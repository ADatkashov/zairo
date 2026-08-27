import 'package:core_network/core_network.dart';

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
}
