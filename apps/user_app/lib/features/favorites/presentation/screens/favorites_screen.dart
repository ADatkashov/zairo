import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logged_out_gate.dart';
import '../../../booking/presentation/screens/provider_detail_screen.dart';
import '../../../discovery/data/models/provider_search_result.dart';
import '../../../discovery/presentation/widgets/provider_card.dart';
import '../providers/favorites_providers.dart';

/// Reached directly from the bottom nav (a peer tab to Home/Search/
/// Bookings/Profile, not only pushed after already being logged in), so it
/// resolves the current user itself instead of requiring a caller to pass
/// one — see LoggedOutGate for the logged-out path.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.myFavoritesTitle),
      body: authState.when(
        data: (user) => user == null
            ? LoggedOutGate(icon: Icons.favorite_border_rounded, message: l10n.favoritesLoggedOutPrompt)
            : _FavoritesList(userId: user.id),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric(error.toString()),
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoritesList extends ConsumerWidget {
  final String userId;

  const _FavoritesList({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final favoritesAsync = ref.watch(myFavoritesProvider(userId));

    return favoritesAsync.when(
      data: (favorites) {
        if (favorites.isEmpty) {
          return Center(
            child: FactoryEmptyState(
              icon: Icons.favorite_border_rounded,
              title: l10n.favoritesEmptyTitle,
              message: l10n.favoritesEmptyMessage,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          itemCount: favorites.length,
          separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
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
              averageRating: favorite.averageRating,
              reviewCount: favorite.reviewCount,
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
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: FactoryErrorState(
            message: l10n.errorFavoritesLoadFailed,
            onRetry: () => ref.invalidate(myFavoritesProvider(userId)),
          ),
        ),
      ),
    );
  }
}
