import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logged_out_gate.dart';
import '../../../booking/presentation/screens/provider_detail_screen.dart';
import '../../../discovery/data/models/provider_search_result.dart';
import '../../../discovery/presentation/widgets/provider_card.dart';
import '../../data/models/favorite_provider.dart';
import '../providers/favorites_providers.dart';

/// Pushed from Profile's favorites stat tile, not its own bottom-nav tab
/// (see app_router.dart's doc comment on why). Resolves the current user
/// itself via [authControllerProvider] rather than taking a userId
/// constructor param — same as before this moved off the tab bar, and
/// still needed for [LoggedOutGate]'s path regardless of caller.
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
        loading: () => const FactoryLoadingState(),
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

  Future<void> _confirmAndClearAll(BuildContext context, WidgetRef ref, List<FavoriteProvider> favorites) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.favoritesClearAllConfirmTitle,
      message: l10n.favoritesClearAllConfirmMessage,
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.favoritesClearAllKeepButton,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.favoritesClearAllButton,
            variant: FactoryButtonVariant.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true) return;

    final api = ref.read(favoritesApiProvider);
    // Snapshotted ids, not a lazy map over favorites — that list is the
    // exact object myFavoritesProvider holds, and a removeFavorite
    // implementation that mutates its backing store as it resolves (as a
    // fake/in-memory one might) would otherwise race Future.wait's
    // iteration of it.
    final providerIds = favorites.map((f) => f.id).toList();
    await Future.wait(providerIds.map((id) => api.removeFavorite(userId, id)));
    ref.invalidate(myFavoritesProvider(userId));
  }

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
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FactorySpacing.space4,
                  FactorySpacing.space2,
                  FactorySpacing.space4,
                  0,
                ),
                child: FactoryButton(
                  label: l10n.favoritesClearAllButton,
                  variant: FactoryButtonVariant.text,
                  onPressed: () => _confirmAndClearAll(context, ref, favorites),
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                // A 2-column grid of vertical cards (Customer App Redesign
                // board, 2026-09-05) — Favorites is a saved-items gallery,
                // not a results list, so it reads better as a grid than
                // Search's photo-left rows.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: FactorySpacing.space3,
                  crossAxisSpacing: FactorySpacing.space3,
                  childAspectRatio: 0.78,
                ),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final favorite = favorites[index];
                  // ProviderCard expects a ProviderSearchResult — same
                  // shape, built here rather than widening ProviderCard's
                  // API to accept either type.
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
                    layout: FactoryProviderCardLayout.vertical,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: asSearchResult)),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const FactoryLoadingState(),
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
