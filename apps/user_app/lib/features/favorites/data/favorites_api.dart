import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'models/favorite_provider.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as the other feature APIs.
class FavoritesApi {
  final DioClient _dioClient;

  FavoritesApi(this._dioClient);

  Future<List<FavoriteProvider>> listFavorites(String userId) async {
    final response = await _dioClient.get('/users/$userId/favorites');
    final data = response.data as List<dynamic>;
    return data.map((e) => FavoriteProvider.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// A 404 here means "not favorited" — a normal state, not an error.
  Future<bool> isFavorited(String userId, String providerId) async {
    try {
      await _dioClient.get('/users/$userId/favorites/$providerId');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return false;
      }
      rethrow;
    }
  }

  /// Idempotent on the backend — safe to call even if already favorited.
  Future<void> addFavorite(String userId, String providerId) {
    return _dioClient.post('/users/$userId/favorites/$providerId');
  }

  /// Idempotent on the backend — safe to call even if not favorited.
  Future<void> removeFavorite(String userId, String providerId) async {
    await _dioClient.delete('/users/$userId/favorites/$providerId');
  }
}
