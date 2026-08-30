import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_api.dart';
import '../../data/models/business_type.dart';
import '../../data/models/catalog_service.dart';
import '../../data/models/category.dart';
import '../../data/models/subsphere.dart';

final catalogApiProvider = Provider<CatalogApi>((ref) {
  return CatalogApi(ref.watch(dioClientProvider));
});

/// The master catalog's top level — the dashboard's business-creation
/// picker reads this instead of a hardcoded (beauty/auto/cleaning) triple.
final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(catalogApiProvider).listCategories();
});

final businessTypesProvider = FutureProvider.autoDispose.family<List<BusinessType>, String>((ref, categoryId) {
  return ref.watch(catalogApiProvider).listBusinessTypes(categoryId);
});

final subspheresProvider = FutureProvider.autoDispose.family<List<Subsphere>, String>((ref, businessTypeId) {
  return ref.watch(catalogApiProvider).listSubspheres(businessTypeId);
});

final catalogServicesProvider = FutureProvider.autoDispose.family<List<CatalogServiceModel>, String>(
  (ref, businessTypeId) {
    return ref.watch(catalogApiProvider).listServicesByBusinessType(businessTypeId);
  },
);
