import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_api.dart';
import '../../data/models/business_type.dart';
import '../../data/models/category.dart';

final catalogApiProvider = Provider<CatalogApi>((ref) {
  return CatalogApi(ref.watch(dioClientProvider));
});

/// The master catalog's top level — Home's category grid reads this instead
/// of a hardcoded ("beauty"/"auto") pair. autoDispose: this is cheap to
/// refetch and shouldn't outlive the screen that asked for it, matching
/// every other *Provider in this app's discovery feature.
final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(catalogApiProvider).listCategories();
});

/// A category's spheres, for the drill-down sheet opened from the category
/// grid. Keyed by categoryId so each category's spheres are fetched (and
/// cached) independently.
final businessTypesProvider = FutureProvider.autoDispose.family<List<BusinessType>, String>((ref, categoryId) {
  return ref.watch(catalogApiProvider).listBusinessTypes(categoryId);
});
