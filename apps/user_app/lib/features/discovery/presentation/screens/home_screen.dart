import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/initials.dart';
import '../../../../core/formatting/slot_label.dart';
import '../../../../core/provider_grid.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../maps/data/geo_point.dart';
import '../../../ads/data/models/ad_banner.dart';
import '../../../ads/presentation/providers/ads_providers.dart';
import '../../../ads/presentation/screens/ad_video_screen.dart';
import '../../../ads/presentation/widgets/home_hero_banners.dart';
import '../../../auth/data/models/user_summary.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../booking/data/models/book_again_suggestion.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../../catalog/presentation/category_icon.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../city/presentation/providers/city_providers.dart';
import '../../../maps/presentation/providers/maps_providers.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../workers/data/models/top_worker.dart';
import '../../../workers/presentation/providers/workers_providers.dart';
import '../../../workers/presentation/widgets/master_avatar_card.dart';
import '../../data/models/provider_search_result.dart';
import '../providers/discovery_providers.dart';
import '../widgets/provider_card.dart';

/// The Home tab: curated discovery, not a search box with results glued
/// underneath (that's the Search tab). Tapping the search field switches to
/// Search rather than pushing a new screen, matching how the other bottom
/// nav destinations behave.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    const query = DiscoveryQuery();
    final resultsAsync = ref.watch(searchResultsProvider(query));
    final locationAsync = ref.watch(currentLocationProvider);
    final user = ref.watch(authControllerProvider).value;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return _buildHomeContent(
      context,
      ref,
      l10n,
      query,
      resultsAsync,
      locationAsync,
      user,
      colors,
      textTheme,
    );
  }

  Widget _buildHomeContent(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    DiscoveryQuery query,
    AsyncValue<List<ProviderSearchResult>> resultsAsync,
    AsyncValue<GeoPoint?> locationAsync,
    UserSummary? user,
    FactoryColors colors,
    TextTheme textTheme,
  ) {
    return Scaffold(
      backgroundColor: colors.bg,
      body: resultsAsync.when(
          data: (results) {
            final openCount = results
                .where((r) => r.hasOpenAvailability)
                .length;
            final topRated = results.take(8).toList();
            return RefreshIndicator(
              // The pinned hero bar owns the top inset (see [_HomeHeroBar]), so
              // the spinner is nudged below it instead of hiding under it.
              edgeOffset: _HomeHeroBar.collapsedHeight(context),
              onRefresh: () => ref.refresh(searchResultsProvider(query).future),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _HomeHeroBar(
                    user: user,
                    // Best-effort: no banners (loading, failed, none live) is the plain hero.
                    banners: ref.watch(homeBannersProvider).value ?? const <AdBanner>[],
                    cityLabel: ref
                            .watch(userCurrentCityProvider)
                            .value
                            ?.nameFor(Localizations.localeOf(context).languageCode) ??
                        locationAsync.value?.label ??
                        l10n.homeLocationUnknown,
                    greeting: user != null
                        ? l10n.homeGreeting(user.displayName)
                        : l10n.homeGreetingGuest,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      FactorySpacing.space4,
                      0,
                      FactorySpacing.space4,
                      FactorySpacing.space4,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                  const SizedBox(height: FactorySpacing.space4),
                  _SearchEntry(onTap: () => context.go(AppRoutes.search())),
                  // Categories first, straight under the search: the main way into
                  // the app is "pick what you need", so it is the first thing
                  // below the search field.
                  const SizedBox(height: FactorySpacing.space5),
                  const _CategoriesSection(),
                  // Promos come after the primary action, not in front of it. Only
                  // the live "open slots today" card is left; anything else the
                  // platform wants to promote (bonuses, news) is a banner, run
                  // from the admin console, not a card fixed in the app.
                  if (openCount > 0) ...[
                    const SizedBox(height: FactorySpacing.space5),
                    _PromoStrip(
                      openCount: openCount,
                      onViewAvailable: () => context.go(AppRoutes.search()),
                    ),
                  ],
                  if (user != null) ...[
                    const SizedBox(height: FactorySpacing.space6),
                    _BookAgainSection(userId: user.id),
                    _MyMastersSection(userId: user.id),
                  ],
                  const SizedBox(height: FactorySpacing.space6),
                  FactorySectionHeader(
                    title: l10n.homeTopRatedTitle,
                    actionLabel: l10n.homeSeeAll,
                    onActionTap: () => context.go(AppRoutes.search()),
                  ),
                  const SizedBox(height: FactorySpacing.space3),
                  if (topRated.isEmpty)
                    FactoryEmptyState(
                      compact: true,
                      icon: Symbols.storefront_rounded,
                      title: l10n.homeEmptyTitle,
                      message: l10n.homeEmptyMessage,
                    )
                  else
                    SizedBox(
                      // The card's own height plus the "Book" button under it, and room for larger system text
                      // (the photo keeps its size, the text under it grows).
                      height: 252 +
                          providerCardActionHeight +
                          110 * (MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0) - 1),
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
                            onTap: () => context.push(
                              AppRoutes.provider(result.id),
                              extra: result,
                            ),
                            onBook: () => context.push(
                              AppRoutes.provider(result.id, book: true),
                              extra: result,
                            ),
                          );
                        },
                      ),
                    ),
                  const _TopMastersSection(),
                  const SizedBox(height: FactorySpacing.space6),
                  _RecommendedSection(results: results, excluding: topRated),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SafeArea(child: FactoryLoadingState()),
          error: (error, stackTrace) => SafeArea(
            child: Center(
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

/// The Home header: a gradient hero (the greeting) that collapses on scroll
/// into a pinned bar (avatar, city, favorites, bell) while the rounded content
/// "sheet" slides up over it. The sheet's top edge is the app bar's `bottom`,
/// so it stays attached to the bar at every scroll offset.
class _HomeHeroBar extends StatelessWidget {
  const _HomeHeroBar({
    required this.user,
    required this.banners,
    required this.cityLabel,
    required this.greeting,
  });

  final UserSummary? user;

  /// Live promo banners. When there are any they take the hero over (the cover
  /// image fills it, the greeting steps aside); when there are none it is the
  /// plain green greeting hero.
  final List<AdBanner> banners;
  final String cityLabel;
  final String greeting;

  static const _toolbarHeight = 68.0;
  /// Toolbar + one or two lines of greeting + the sheet lip, no more: the
  /// search and the categories are what people come for, so they start high.
  static const _expandedHeight = 176.0;

  /// Taller than the greeting hero: a banner cover needs room to read as one.
  static const _expandedHeightWithBanners = 320.0;
  static const _sheetRadius = 24.0;

  /// Status bar + toolbar + sheet lip: where scrollable content starts once
  /// the hero is fully collapsed.
  static double collapsedHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + _toolbarHeight + _sheetRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final user = this.user;
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: colors.primaryStrong,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: _toolbarHeight,
      expandedHeight: banners.isEmpty ? _expandedHeight : _expandedHeightWithBanners,
      titleSpacing: FactorySpacing.space4,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FactoryAvatar(
            initials: user != null ? initialsFor(user.displayName) : '?',
            image: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
          ),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: InkWell(
              onTap: () => context.push('/city-selection'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.location_on_rounded, size: 16, color: colors.onPrimary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      cityLabel,
                      style: textTheme.titleSmall?.copyWith(color: colors.onPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Symbols.keyboard_arrow_down_rounded,
                    size: 18,
                    color: colors.onPrimary.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
          const _FavoritesButton(),
          if (user != null) ...[
            const SizedBox(width: FactorySpacing.space2),
            const NotificationBellButton(),
          ],
        ],
      ),
      flexibleSpace: banners.isEmpty ? _greetingSpace(context) : _bannerSpace(context),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_sheetRadius),
        child: Container(
          height: _sheetRadius,
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
          ),
        ),
      ),
    );
  }
  /// The plain hero: gradient, a soft gold glow and the greeting.
  Widget _greetingSpace(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primaryStrong, colors.primary],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.accent.withValues(alpha: 0.45),
                        colors.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: FactorySpacing.space4,
                right: FactorySpacing.space4,
                bottom: _sheetRadius + FactorySpacing.space3,
                child: Text(
                  greeting,
                  // The headline face (Unbounded) is very wide: at large
                  // system text a single name overflows and snaps mid-word.
                  // Cap this one heading's scale and ellipsize instead.
                  textScaler: MediaQuery.textScalerOf(context).clamp(
                    maxScaleFactor: MediaQuery.sizeOf(context).width < 360 ? 1.0 : 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineSmall?.copyWith(color: colors.onPrimary),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// The banner hero: the covers fill the space under the toolbar and fade out
  /// as the bar collapses, so the pinned bar stays a plain green strip.
  Widget _bannerSpace(BuildContext context) {
    final colors = context.factoryColors;
    final topPadding = MediaQuery.paddingOf(context).top;
    final expandedExtent = topPadding + _expandedHeightWithBanners;
    final collapsedExtent = topPadding + _toolbarHeight + _sheetRadius;
    return LayoutBuilder(
      builder: (context, constraints) {
        final t = ((constraints.maxHeight - collapsedExtent) / (expandedExtent - collapsedExtent)).clamp(0.0, 1.0);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.primaryStrong, colors.primary],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: expandedExtent,
              child: IgnorePointer(
                ignoring: t < 0.3,
                child: Opacity(
                  opacity: t,
                  child: HomeHeroBanners(
                    banners: banners,
                    topInset: topPadding + _toolbarHeight,
                    bottomInset: _sheetRadius + FactorySpacing.space6,
                    onOpenVideo: (banner) => context.push(
                      AppRoutes.adVideo,
                      extra: AdVideoArgs(url: banner.videoUrl!, title: banner.title),
                    ),
                    onOpenLink: (target) => switch (target) {
                      AdLinkTarget.rewards => context.push(AppRoutes.rewards),
                      AdLinkTarget.search => context.go(AppRoutes.search()),
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A heart in the header: Favorites used to be reachable only through a
/// small counter tile two levels deep in Profile, and not at all for a guest.
/// A guest lands on Favorites' own log-in gate.
class _FavoritesButton extends StatelessWidget {
  const _FavoritesButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: FactoryRadius.lgRadius,
        border: Border.all(color: colors.border),
      ),
      child: IconButton(
        icon: Icon(Symbols.favorite_rounded, color: colors.text),
        tooltip: l10n.myFavoritesTitle,
        onPressed: () => context.push(AppRoutes.favorites),
      ),
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

/// The Home tab's categories: a heading with an "All ›" link, then a 4×2 grid
/// of categories that scrolls sideways. A launcher, not a filter — one tap on a
/// category opens Search already narrowed to it. The first screen is exactly
/// two rows of four (the catalog's own `sortOrder`, admin-curated, decides the
/// order); the rest follow as further 4×2 pages to the right, so Home stays two
/// rows tall however large the catalog grows. With more than eight categories
/// the next column peeks at the screen edge as the cue to swipe; "All ›" still
/// opens [AllCategoriesScreen] for the whole list in one view.
class _CategoriesSection extends ConsumerWidget {
  const _CategoriesSection();

  static const _columns = 4;

  /// One page: two rows of four.
  static const _pageSize = _columns * 2;

  static const _gap = FactorySpacing.space2;

  /// How many columns are on screen when the grid scrolls: the fourth plus a
  /// sliver of the fifth.
  static const _visibleColumnsWhenScrolling = 4.4;

  // FactoryCategoryTile's own content is 72px of chrome (4px padding + 56px
  // icon circle + 8px gap + 4px padding) plus up to two label lines. The label
  // height follows the user's text scale so large system fonts don't clip the
  // second line.
  static double _tileHeightFor(BuildContext context) =>
      72 + 2 * MediaQuery.textScalerOf(context).scale(13 * 1.2) + 4;

  Future<void> _openAllCategories(BuildContext context) async {
    final code = await context.push<String>(AppRoutes.categories);
    if (code != null && context.mounted) context.go(AppRoutes.search(category: code));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categoriesAsync = ref.watch(categoriesProvider);
    final languageCode = Localizations.localeOf(context).languageCode;
    final tileHeight = _tileHeightFor(context);

    return Column(
      // Stretch: the heading needs the full width to push "All ›" to the right edge.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactorySectionHeader(
          title: l10n.homeCategoriesTitle,
          actionLabel: l10n.homeCategoriesAll,
          onActionTap: () => _openAllCategories(context),
        ),
        const SizedBox(height: FactorySpacing.space3),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final cells = categoriesAsync.when(
              data: (categories) => [
                for (final category in categories) (category.code, category.nameFor(languageCode)),
              ],
              // Best-effort: while loading, hold the grid's place with skeletons;
              // on error draw no grid (the "All ›" link above still works and its
              // screen has its own retry) rather than blocking Home on the catalog.
              loading: () => [for (var i = 0; i < _pageSize; i++) null],
              error: (error, stackTrace) => const <(String, String)?>[],
            );
            if (cells.isEmpty) return const SizedBox.shrink();

            final scrolls = cells.length > _pageSize;
            final visible = scrolls ? _visibleColumnsWhenScrolling : _columns.toDouble();
            // The cell is the label's width: a narrow phone has no room to spare.
            final cell = (width - _gap * (visible.ceil() - 1)) / visible;
            final dense = cell < 76;

            Widget tile((String, String)? entry) {
              if (entry == null) {
                return FactorySkeleton(
                  width: cell,
                  height: tileHeight,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                );
              }
              final (code, label) = entry;
              final accent = colorForCategory(context, code);
              // The label may use the gap beside its cell too: a long single word ("Образование") would otherwise
              // break in the middle at 320-390 px. The tile is at most as wide as the cell plus that gap.
              return SizedBox(
                height: tileHeight,
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxWidth: cell + _gap,
                  maxHeight: tileHeight,
                  child: FactoryCategoryTile(
                    icon: iconForCategory(code),
                    label: label,
                    labelMaxWidth: cell + _gap,
                    dense: dense,
                    accentColor: accent?.color,
                    accentTint: accent?.tint,
                    onTap: () => context.go(AppRoutes.search(category: code)),
                  ),
                ),
              );
            }

            // Page k holds items 8k..8k+7 as 4 columns × 2 rows, so the first
            // screen reads exactly like the plain grid: 1-4 on top, 5-8 below.
            // A half-filled last page only gets the columns it needs, so the
            // grid doesn't scroll over empty space (a lone page keeps all four
            // so its tiles stay on the grid).
            final fullPages = cells.length ~/ _pageSize;
            final rest = cells.length % _pageSize;
            final columnCount = scrolls ? fullPages * _columns + (rest < _columns ? rest : _columns) : _columns;
            int indexAt(int column, int row) => (column ~/ _columns) * _pageSize + row * _columns + column % _columns;
            final columns = <Widget>[
              for (var c = 0; c < columnCount; c++)
                SizedBox(
                  width: cell,
                  child: Column(
                    children: [
                      for (var row = 0; row < 2; row++) ...[
                        if (row > 0) const SizedBox(height: _gap),
                        if (indexAt(c, row) < cells.length)
                          Center(child: tile(cells[indexAt(c, row)]))
                        else
                          // Keeps the empty slot's height so a lone tile stays in the top row.
                          SizedBox(height: tileHeight),
                      ],
                    ],
                  ),
                ),
            ];

            final grid = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  columns[i],
                ],
              ],
            );
            if (!scrolls) return grid;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // Let the next column run to the screen edge instead of being cut
              // at the page padding — the cue that the grid scrolls.
              clipBehavior: Clip.none,
              child: grid,
            );
          },
        ),
      ],
    );
  }
}

/// "Best masters": a rail of avatars of the best-rated masters. A tap opens the
/// master's own page (rating, services, "Book"), not the business — the person
/// picked a face, so that is where they land. Best-effort like the banners: no
/// section while loading, on error, or while nobody has enough reviews yet.
class _TopMastersSection extends ConsumerWidget {
  const _TopMastersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workers = ref.watch(topWorkersProvider).value ?? const <TopWorker>[];
    if (workers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: FactorySpacing.space6),
        Text(l10n.homeTopMastersTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: FactorySpacing.space3),
        SizedBox(
          height: MasterAvatarCard.heightFor(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: workers.length,
            separatorBuilder: (_, _) => const SizedBox(width: FactorySpacing.space3),
            itemBuilder: (context, index) {
              final worker = workers[index];
              return MasterAvatarCard(
                displayName: worker.displayName,
                photoUrl: worker.photoUrl,
                averageRating: worker.averageRating,
                reviewCount: worker.reviewCount,
                onTap: () => context.push(AppRoutes.worker(worker.id)),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The customer's favourite masters with the time each is next free: the shortest road back to "my" person.
/// Best-effort like [_BookAgainSection] — nothing at all while loading, on error, or with no favourites yet.
class _MyMastersSection extends ConsumerWidget {
  const _MyMastersSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final masters = ref.watch(myFavoriteWorkersProvider(userId)).value ?? const [];
    if (masters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: FactorySpacing.space6),
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
          height: 134 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: FactorySpacing.space3),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return _BookAgainCard(
                suggestion: suggestion,
                // Straight to the booking steps with the same service picked: the customer
                // only has to choose a time.
                onTap: () => context.push(
                  AppRoutes.provider(suggestion.providerId, book: true, serviceId: suggestion.serviceId),
                  extra: suggestion.toProviderSearchResult(),
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
    final l10n = AppLocalizations.of(context)!;
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
              const SizedBox(height: 2),
              Text(
                l10n.homeBookAgainLastVisit(
                  DateFormat.MMMd(Localizations.localeOf(context).toString())
                      .format(suggestion.lastVisitAt.toLocal()),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary),
              ),
              if (suggestion.nextFreeAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.homeBookAgainNextFree(
                    DateFormat.MMMd(Localizations.localeOf(context).toString())
                        .add_Hm()
                        .format(suggestion.nextFreeAt!.toLocal()),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.primary),
                ),
              ],
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
              onTap: () => context.push(
                AppRoutes.provider(result.id),
                extra: result,
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

/// The "open slots today" promo under the launcher: a live count of nearby
/// businesses with a free slot, which no admin-made banner can show. Shown only
/// when there is something to show. It is the only card here, so it spans the
/// page width like the search field above it instead of leaving a gap at the right.
class _PromoStrip extends StatelessWidget {
  const _PromoStrip({required this.openCount, required this.onViewAvailable});

  final int openCount;
  final VoidCallback onViewAvailable;

  static const _cardHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryPromoCard(
      height: _cardHeight,
      title: l10n.homeAvailabilityHero(openCount),
      icon: Symbols.event_available_rounded,
      onTap: onViewAvailable,
    );
  }
}
