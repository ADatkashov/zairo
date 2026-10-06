import 'package:core_network/core_network.dart';

import 'models/business_type.dart';
import 'models/catalog_service.dart';
import 'models/category.dart';
import 'models/subsphere.dart';

/// Public reads of the master catalog (categories, spheres, subspheres,
/// services) — what a business picks from. Managing the catalog is the
/// platform console's job (`apps/platform_admin`), not this app's.
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
}
