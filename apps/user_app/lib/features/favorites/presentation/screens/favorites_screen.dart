import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../booking/presentation/screens/provider_detail_screen.dart';
import '../../../discovery/data/models/provider_search_result.dart';
import '../../../discovery/presentation/widgets/provider_card.dart';
import '../providers/favorites_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  final String userId;

  const FavoritesScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(myFavoritesProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('My favorites')),
      body: favoritesAsync.when(
        data: (favorites) {
          if (favorites.isEmpty) {
            return const Center(child: Text('No favorites yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favorite = favorites[index];
              // ProviderCard expects a ProviderSearchResult — same shape,
              // built here rather than widening ProviderCard's API to
              // accept either type.
              final asSearchResult = ProviderSearchResult(
                id: favorite.id,
                name: favorite.name,
                vertical: favorite.vertical,
                status: favorite.status,
                hasOpenAvailability: favorite.hasOpenAvailability,
                minPrice: favorite.minPrice,
                services: favorite.services,
              );
              return ProviderCard(
                result: asSearchResult,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: asSearchResult)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Failed to load favorites: $error')),
      ),
    );
  }
}
