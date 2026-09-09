import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/initials.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../booking/data/models/book_again_suggestion.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../../booking/presentation/screens/provider_detail_screen.dart';
import '../../../catalog/presentation/category_icon.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../catalog/presentation/screens/all_categories_screen.dart';
import '../../../maps/presentation/providers/maps_providers.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../data/models/provider_search_result.dart';
import '../../data/models/service_summary.dart';
import '../providers/discovery_providers.dart';
import '../widgets/provider_card.dart';

/// The Home tab: curated discovery, not a search box with results glued
/// underneath (that's the Search tab). Tapping the search field switches to
/// Search rather than pushing a new screen, matching how the other bottom
/// nav destinations behave.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// null = every vertical. Set to a Category's `code` (see
  /// catalog_providers.dart) — the search endpoint's `vertical` filter is
  /// unchanged, this just sources the value from the master catalog instead
  /// of a literal string.
  String? _vertical;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = DiscoveryQuery(vertical: _vertical);
    final resultsAsync = ref.watch(searchResultsProvider(query));
    final locationAsync = ref.watch(currentLocationProvider);
    final user = ref.watch(authControllerProvider).value;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: resultsAsync.when(
          data: (results) {
            final openCount = results
                .where((r) => r.hasOpenAvailability)
                .length;
            final topRated = results.take(8).toList();
            return RefreshIndicator(
              onRefresh: () => ref.refresh(searchResultsProvider(query).future),
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FactoryAvatar(
                        initials: user != null
                            ? initialsFor(user.displayName)
                            : '?',
                        image: user?.avatarUrl != null
                            ? NetworkImage(user!.avatarUrl!)
                            : null,
                      ),
                      const SizedBox(width: FactorySpacing.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Symbols.location_on_rounded,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  locationAsync.value?.label ??
                                      l10n.homeLocationUnknown,
                                  style: textTheme.titleSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: FactorySpacing.space1),
                            Text(
                              user != null
                                  ? l10n.homeGreeting(user.displayName)
                                  : l10n.homeGreetingGuest,
                              style: textTheme.headlineSmall?.copyWith(
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (user != null) const _NotificationBellButton(),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.space4),
                  _SearchEntry(onTap: () => context.go('/search')),
                  const SizedBox(height: FactorySpacing.space4),
                  Text(l10n.homeCategoriesTitle, style: textTheme.titleSmall),
                  const SizedBox(height: FactorySpacing.space3),
                  _CategoryGrid(
                    selectedCode: _vertical,
                    onSelect: (code) => setState(() => _vertical = code),
                  ),
                  if (openCount > 0) ...[
                    const SizedBox(height: FactorySpacing.space5),
                    _AvailabilityHero(
                      count: openCount,
                      onViewAll: () => context.go('/search'),
                    ),
                  ],
                  if (user != null) ...[
                    const SizedBox(height: FactorySpacing.space6),
                    _BookAgainSection(userId: user.id),
                  ],
                  const SizedBox(height: FactorySpacing.space6),
                  FactorySectionHeader(
                    title: l10n.homeTopRatedTitle,
                    actionLabel: l10n.homeSeeAll,
                    onActionTap: () => context.go('/search'),
                  ),
                  const SizedBox(height: FactorySpacing.space3),
                  if (topRated.isEmpty)
                    FactoryEmptyState(
                      icon: Symbols.storefront_rounded,
                      title: l10n.homeEmptyTitle,
                      message: l10n.homeEmptyMessage,
                    )
                  else
                    SizedBox(
                      // Tall enough for a title + meta row + a footer that
                      // may wrap to two lines (see ProviderCard's Wrap
                      // footer — a long availability label doesn't always
                      // fit next to the price on one line).
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: topRated.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: FactorySpacing.space3),
                        itemBuilder: (context, index) {
                          final result = topRated[index];
                          return ProviderCard(
                            result: result,
                            layout: FactoryProviderCardLayout.vertical,
                            width: 168,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProviderDetailScreen(provider: result),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: FactorySpacing.space6),
                  _RecommendedSection(results: results, excluding: topRated),
                ],
              ),
            );
          },
          loading: () => const FactoryLoadingState(),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              child: FactoryErrorState(
                message: l10n.errorHomeFeedLoadFailed,
                onRetry: () => ref.invalidate(searchResultsProvider(query)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bell button with an unread-count badge (Customer App Redesign board,
/// 2026-09-05) — pushes [NotificationsScreen] rather than something inline,
/// same reasoning as Profile's favorites stat tile pushing [FavoritesScreen].
class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final userId = ref.watch(authControllerProvider).value?.id;
    final unreadCount = userId == null
        ? 0
        : ref.watch(unreadNotificationsCountProvider(userId)).value ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: FactoryRadius.lgRadius,
            border: Border.all(color: colors.border),
          ),
          child: IconButton(
            icon: Icon(Symbols.notifications_rounded, color: colors.text),
            tooltip: l10n.notificationBellTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors.coral,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: FactoryRadius.xlRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FactorySpacing.space4,
            vertical: FactorySpacing.space3,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: FactoryRadius.xlRadius,
            border: Border.all(color: colors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.05),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Symbols.search_rounded,
                size: 20,
                color: colors.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.homeSearchPrompt,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.textTertiary),
                ),
              ),
              Icon(Symbols.tune_rounded, size: 18, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Home tab's "Популярное" row — a short, curated shortlist, not the
/// master catalog: at most [_popularCount] categories (the catalog's own
/// `sortOrder`, admin-curated, decides which), plus a trailing tile that
/// opens [AllCategoriesScreen] for the other ~14+. Deliberately never grows
/// with the catalog — that was the previous version's actual problem (a
/// wrapping grid of all 20 ran to 4-5 rows and pushed every other Home
/// section below the fold), and Home showing every category is exactly
/// what turns a discovery screen into a category catalog.
///
/// Tapping a shown category toggles the search-vertical filter (tap again
/// to clear); tapping the trailing tile pushes [AllCategoriesScreen] and,
/// if the user picks something there, applies its category `code` here the
/// same way.
class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({required this.selectedCode, required this.onSelect});

  final String? selectedCode;
  final ValueChanged<String?> onSelect;

  static const _popularCount = 6;

  // FactoryCategoryTile's own content is 88px tall (4px padding + 56px icon
  // circle + 8px gap + one label line + 4px padding) — a plain Wrap never
  // exposed this since it sizes each child to its natural height, but a
  // horizontal ListView hard-constrains the cross axis to whatever this is,
  // so it has to be at least that. A few extra px of headroom over the
  // exact figure absorbs minor text-scale/locale line-height variance.
  static const _tileHeight = 96.0;

  Future<void> _openAllCategories(BuildContext context) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const AllCategoriesScreen()),
    );
    if (code != null) onSelect(code);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categoriesAsync = ref.watch(categoriesProvider);
    final languageCode = Localizations.localeOf(context).languageCode;

    final allCategoriesTile = FactoryCategoryTile(
      icon: Symbols.apps_rounded,
      label: l10n.allCategoriesTitle,
      onTap: () => _openAllCategories(context),
    );

    return SizedBox(
      height: _tileHeight,
      child: categoriesAsync.when(
        data: (categories) {
          final popular = categories.take(_popularCount).toList();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: popular.length + 1,
            separatorBuilder: (_, _) =>
                const SizedBox(width: FactorySpacing.space3),
            itemBuilder: (context, index) {
              if (index == popular.length) return allCategoriesTile;
              final category = popular[index];
              final selected = selectedCode == category.code;
              final accent = colorForCategory(context, category.code);
              return FactoryCategoryTile(
                icon: iconForCategory(category.code),
                emoji: category.icon,
                label: category.nameFor(languageCode),
                selected: selected,
                accentColor: accent?.color,
                accentTint: accent?.tint,
                onTap: () => onSelect(selected ? null : category.code),
              );
            },
          );
        },
        // Best-effort: while loading or on error, still show the trailing
        // tile (it doesn't depend on this request) rather than blocking the
        // whole Home screen on the catalog request.
        loading: () => ListView(
          scrollDirection: Axis.horizontal,
          children: [
            const FactorySkeleton(
              width: 64,
              height: _tileHeight,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            const SizedBox(width: FactorySpacing.space3),
            const FactorySkeleton(
              width: 64,
              height: _tileHeight,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            const SizedBox(width: FactorySpacing.space3),
            allCategoriesTile,
          ],
        ),
        error: (error, stackTrace) => ListView(
          scrollDirection: Axis.horizontal,
          children: [allCategoriesTile],
        ),
      ),
    );
  }
}

class _BookAgainSection extends ConsumerWidget {
  const _BookAgainSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final suggestionsAsync = ref.watch(bookAgainSuggestionsProvider(userId));

    // Best-effort: no section at all while loading, on error, or when the
    // customer has no completed bookings yet — this is a bonus shortcut on
    // top of the main discovery feed, not something worth a loading
    // skeleton or error state of its own.
    final suggestions = suggestionsAsync.value ?? const [];
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeBookAgainTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: FactorySpacing.space3),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: FactorySpacing.space3),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return _BookAgainCard(
                suggestion: suggestion,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderDetailScreen(
                      provider: ProviderSearchResult(
                        id: suggestion.providerId,
                        name: suggestion.providerName,
                        vertical: suggestion.vertical,
                        status: 'ACTIVE',
                        hasOpenAvailability: true,
                        minPrice: suggestion.price,
                        services: [
                          ServiceSummary(
                            id: suggestion.serviceId,
                            title: suggestion.serviceTitle,
                            durationMinutes: suggestion.durationMinutes,
                            price: suggestion.price,
                            currency: suggestion.currency,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BookAgainCard extends StatelessWidget {
  const _BookAgainCard({required this.suggestion, required this.onTap});

  final BookAgainSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: FactoryRadius.mdRadius,
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(FactorySpacing.space3),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: FactoryRadius.mdRadius,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                suggestion.providerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: colors.text),
              ),
              const SizedBox(height: 2),
              Text(
                suggestion.serviceTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary),
              ),
              const Spacer(),
              FactoryPriceText(
                amount: suggestion.price,
                currencySymbol: suggestion.currency,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Recommended for you" (Customer App Redesign board, 2026-09-05) — the
/// simple heuristic behind it: highest-rated providers in this search
/// result, [excluding] whatever the Top Rated carousel above already shows
/// so the two sections don't just repeat each other. No personalization
/// beyond that exists yet (no purchase-history/collaborative-filtering
/// signal to draw on) — a provider with no reviews yet never appears here,
/// same "absent, not zero" reasoning as everywhere else rating is shown.
class _RecommendedSection extends StatelessWidget {
  const _RecommendedSection({required this.results, required this.excluding});

  final List<ProviderSearchResult> results;
  final List<ProviderSearchResult> excluding;

  static const _maxCount = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final excludedIds = excluding.map((r) => r.id).toSet();
    final recommended =
        results
            .where(
              (r) => r.averageRating != null && !excludedIds.contains(r.id),
            )
            .toList()
          ..sort((a, b) => b.averageRating!.compareTo(a.averageRating!));
    if (recommended.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeRecommendedTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: FactorySpacing.space3),
        for (final result in recommended.take(_maxCount))
          Padding(
            padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
            child: _RecommendedRow(
              result: result,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProviderDetailScreen(provider: result),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecommendedRow extends StatelessWidget {
  const _RecommendedRow({required this.result, required this.onTap});

  final ProviderSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactoryCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FactorySpacing.space2),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: FactoryRadius.mdRadius,
            ),
            child: Icon(
              iconForCategory(result.vertical),
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Symbols.star_rounded,
                      fill: 1,
                      size: 14,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      result.averageRating!.toStringAsFixed(1),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (result.distanceKm != null) ...[
                      Text(
                        ' · ',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        l10n.distanceKmShort(
                          result.distanceKm!.toStringAsFixed(1),
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (result.minPrice != null)
            FactoryPriceText(
              amount: result.minPrice!,
              currencySymbol: result.services.isNotEmpty
                  ? result.services.first.currency
                  : '',
              fontSize: 13,
            ),
        ],
      ),
    );
  }
}

/// A deliberate gradient case (`primaryStrong` → `mint` diagonal, two soft
/// translucent circles) — everywhere else in Factory is flat color, this
/// pattern reserved for one hero moment per app (business_admin's Dashboard
/// overview hero is the other). Customer App Redesign board, 2026-09-05.
class _AvailabilityHero extends StatelessWidget {
  const _AvailabilityHero({required this.count, required this.onViewAll});

  final int count;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(FactorySpacing.space5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryStrong, colors.mint],
        ),
        borderRadius: FactoryRadius.xxlRadius,
        boxShadow: [
          BoxShadow(
            color: colors.primaryStrong.withValues(alpha: 0.28),
            offset: const Offset(0, 16),
            blurRadius: 32,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: _HeroCircle(size: 140, opacity: 0.12),
          ),
          Positioned(
            bottom: -40,
            right: 40,
            child: _HeroCircle(size: 90, opacity: 0.1),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeAvailabilityEyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: FactorySpacing.space2),
              Text(
                l10n.homeAvailabilityHero(count),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: colors.onPrimary),
              ),
              const SizedBox(height: FactorySpacing.space3),
              Material(
                color: Colors.white,
                shape: FactoryRadius.pill,
                child: InkWell(
                  onTap: onViewAll,
                  customBorder: FactoryRadius.pill,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    child: Text(
                      l10n.homeSeeAll,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: colors.primaryStrong),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCircle extends StatelessWidget {
  const _HeroCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
