import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/favorites_api.dart';
import '../../data/models/favorite_provider.dart';

final favoritesApiProvider = Provider<FavoritesApi>((ref) {
  return FavoritesApi(ref.watch(dioClientProvider));
});

final myFavoritesProvider = FutureProvider.autoDispose.family<List<FavoriteProvider>, String>((ref, userId) {
  return ref.watch(favoritesApiProvider).listFavorites(userId);
});

/// Keyed by a (userId, providerId) record — Dart records have structural
/// equality, so this works as a Riverpod family key without a hand-rolled
/// value class.
final isFavoritedProvider =
    FutureProvider.autoDispose.family<bool, ({String userId, String providerId})>((ref, key) {
  return ref.watch(favoritesApiProvider).isFavorited(key.userId, key.providerId);
});
