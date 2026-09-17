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

/// The Platform Admin taxonomy screen's own list — every status, not just
/// ACTIVE, so deactivating a category doesn't drop it out of the screen
/// that can reactivate it. See CatalogApi.listAllCategories.
final platformAllCategoriesProvider = FutureProvider.autoDispose.family<List<Category>, String>((ref, platformToken) {
  return ref.watch(catalogApiProvider).listAllCategories(platformToken);
});

final platformAllBusinessTypesProvider =
    FutureProvider.autoDispose.family<List<BusinessType>, (String platformToken, String categoryId)>((ref, key) {
  return ref.watch(catalogApiProvider).listAllBusinessTypes(key.$1, key.$2);
});

final platformAllSubspheresProvider =
    FutureProvider.autoDispose.family<List<Subsphere>, (String platformToken, String businessTypeId)>((ref, key) {
  return ref.watch(catalogApiProvider).listAllSubspheres(key.$1, key.$2);
});

final platformAllCatalogServicesProvider =
    FutureProvider.autoDispose.family<List<CatalogServiceModel>, (String platformToken, String businessTypeId)>(
        (ref, key) {
  return ref.watch(catalogApiProvider).listAllCatalogServices(key.$1, key.$2);
});
