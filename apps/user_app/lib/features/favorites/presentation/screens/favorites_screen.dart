import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import '../../../../core/provider_grid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/slot_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logged_out_gate.dart';
import '../../../discovery/data/models/provider_search_result.dart';
import '../../../discovery/presentation/widgets/provider_card.dart';
import '../../../workers/presentation/providers/workers_providers.dart';
import '../../../workers/presentation/widgets/master_avatar_card.dart';
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
            ? LoggedOutGate(
                icon: Symbols.favorite_rounded,
                message: l10n.favoritesLoggedOutPrompt,
              )
            : _FavoritesList(userId: user.id),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric,
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

  Future<void> _confirmAndClearAll(
    BuildContext context,
    WidgetRef ref,
    List<FavoriteProvider> favorites,
  ) async {
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
        Future<void> refresh() => ref.refresh(myFavoritesProvider(userId).future);

        if (favorites.isEmpty) {
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _MyMastersRail(userId: userId),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: FactoryEmptyState(
                      icon: Symbols.favorite_rounded,
                      title: l10n.favoritesEmptyTitle,
                      message: l10n.favoritesEmptyMessage,
                      actionLabel: l10n.favoritesBrowseButton,
                      onAction: () => context.go(AppRoutes.search()),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            _MyMastersRail(userId: userId),
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
              child: RefreshIndicator(
                onRefresh: refresh,
                child: GridView.builder(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                // A 2-column grid of vertical cards (Customer App Redesign
                // board, 2026-09-05) — Favorites is a saved-items gallery,
                // not a results list, so it reads better as a grid than
                // Search's photo-left rows.
                gridDelegate: providerGridDelegate(
                  context,
                  crossAxisCount: providerGridColumns(context),
                  spacing: FactorySpacing.space3,
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
                    onTap: () => context.push(
                      AppRoutes.provider(asSearchResult.id),
                      extra: asSearchResult,
                    ),
                  );
                },
                ),
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

/// "My masters": the people the customer put a heart on, as avatars that open the master's page. Best-effort and
/// silent like Home's rails — nothing at all while loading, on error, or when the list is empty.
class _MyMastersRail extends ConsumerWidget {
  const _MyMastersRail({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final masters = ref.watch(myFavoriteWorkersProvider(userId)).value ?? const [];
    if (masters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(FactorySpacing.space4, FactorySpacing.space4, FactorySpacing.space4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.favoritesMyMastersTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: FactorySpacing.space3),
          SizedBox(
            height: MasterAvatarCard.heightFor(context, withCaption: masters.any((m) => m.nextFreeAt != null)),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: masters.length,
              separatorBuilder: (_, _) => const SizedBox(width: FactorySpacing.space3),
              itemBuilder: (context, index) {
                final master = masters[index];
                return MasterAvatarCard(
                  displayName: master.displayName,
                  photoUrl: master.photoUrl,
                  averageRating: master.averageRating,
                  reviewCount: master.reviewCount,
                  caption: master.nextFreeAt == null
                      ? null
                      : slotLabel(l10n, locale, DateTime.now(), master.nextFreeAt!.toLocal()),
                  onTap: () => context.push(AppRoutes.worker(master.id)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
