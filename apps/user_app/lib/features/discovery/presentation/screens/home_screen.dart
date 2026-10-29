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
import '../../../ads/presentation/widgets/home_banner_carousel.dart';
import '../../../auth/data/models/user_summary.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../booking/data/models/book_again_suggestion.dart';
import '../../../booking/data/models/booking.dart';
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
import '../../data/models/recommended_provider.dart';
import '../../popular_services.dart';
import '../../../booking/next_booking.dart';
import '../providers/discovery_providers.dart';
import '../widgets/provider_card.dart';

/// Which Home to draw. [reference] is the clean layout; [classic] is the previous one (green hero, quick chips, 4x2
/// category grid, popular-services rail), kept as it was so it can come back without being rewritten.
enum HomeLayout {
  /// Greeting and city, search, the banner, one row of categories, "Top services" as a list; the personal and
  /// discovery rails (book again, my masters, nearby, best masters, recommended) follow below the first screen.
  reference,

  /// The layout before the reference redesign.
  classic,
}

/// The Home tab: curated discovery, not a search box with results glued
/// underneath (that's the Search tab). Tapping the search field, a category or
/// a top service opens Search already set up for it. Order is by what people
/// came to do: search, then where to go next; rails after.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.layout = HomeLayout.reference});

  final HomeLayout layout;

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
            // "Top rated" only when there are ratings to rank by: three or more rated businesses, best first.
            // Otherwise the row is simply what is near, under a title that does not claim more than it knows.
            final rated = results
                .where((r) => (r.averageRating ?? 0) > 0 && (r.reviewCount ?? 0) > 0)
                .toList()
              ..sort((a, b) {
                final byRating = b.averageRating!.compareTo(a.averageRating!);
                return byRating != 0 ? byRating : (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
              });
            final hasTopRated = rated.length >= 3;
            final topRated = (hasTopRated ? rated : results).take(8).toList();
            // The rails under the first screen: personal first (book again, my masters), then what is near and who is best.
            final lower = <Widget>[
              if (user != null) ...[
                    const SizedBox(height: FactorySpacing.space6),
                    _BookAgainSection(userId: user.id),
                    _MyMastersSection(userId: user.id),
                  ],
                  const SizedBox(height: FactorySpacing.space6),
                  FactorySectionHeader(
                    title: hasTopRated ? l10n.homeTopRatedTitle : l10n.homeNearbyTitle,
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
                  _RecommendedSection(results: results, excluding: topRated, userId: user?.id),
            ];
            final cityLabel = ref
                    .watch(userCurrentCityProvider)
                    .value
                    ?.nameFor(Localizations.localeOf(context).languageCode) ??
                locationAsync.value?.label ??
                l10n.homeLocationUnknown;
            final greeting = user != null ? l10n.homeGreeting(user.displayName) : l10n.homeGreetingGuest;
            if (layout == HomeLayout.reference) {
              return RefreshIndicator(
                onRefresh: () => ref.refresh(searchResultsProvider(query).future),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverSafeArea(
                      sliver: SliverPadding(
                        padding: const EdgeInsets.all(FactorySpacing.space4),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _ReferenceHeader(user: user, cityLabel: cityLabel, greeting: greeting),
                            const SizedBox(height: FactorySpacing.space4),
                            _SearchEntry(onTap: () => context.go(AppRoutes.search())),
                            // Someone with a visit coming up wants that first: when, where, in one tap.
                            if (user != null) _NextBookingSection(userId: user.id),
                            // The platform's promo sits where the reference has its hero card, right under the search.
                            const _BannersSection(top: FactorySpacing.space4, height: 128),
                            const SizedBox(height: FactorySpacing.space5),
                            const _CategoriesRow(),
                            _TopServicesSection(results: results),
                            ...lower,
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              // The pinned hero bar owns the top inset (see [_HomeHeroBar]), so
              // the spinner is nudged below it instead of hiding under it.
              edgeOffset: _HomeHeroBar.collapsedHeight(context),
              onRefresh: () => ref.refresh(searchResultsProvider(query).future),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _HomeHeroBar(user: user, cityLabel: cityLabel, greeting: greeting),
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
                  // One tap to the most common narrowings, so the person does not
                  // have to open the filter sheet to get "free today" or "closest".
                  const SizedBox(height: FactorySpacing.space3),
                  const _QuickChips(),
                  // Someone with a visit coming up wants that first: when, where, in one tap.
                  if (user != null) _NextBookingSection(userId: user.id),
                  // Categories next: the main way into the app is "pick what you
                  // need", so it is the first block below the search.
                  const SizedBox(height: FactorySpacing.space5),
                  const _CategoriesSection(),
                  // Promos come after the primary action, not in front of it. The
                  // platform runs them as banners from the admin console.
                  const _BannersSection(),
                  _PopularServicesSection(results: results),
                  ...lower,
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
    required this.cityLabel,
    required this.greeting,
  });

  final UserSummary? user;
  final String cityLabel;
  final String greeting;

  static const _toolbarHeight = 68.0;
  /// Toolbar + one or two lines of greeting + the sheet lip, no more: the
  /// search and the categories are what people come for, so they start high.
  static const _expandedHeight = 176.0;

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
      expandedHeight: _expandedHeight,
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
      flexibleSpace: _greetingSpace(context),
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
class _RecommendedSection extends ConsumerWidget {
  const _RecommendedSection({required this.results, required this.excluding, required this.userId});

  final List<ProviderSearchResult> results;
  final List<ProviderSearchResult> excluding;

  /// The logged-in customer, whose own history can personalize the list; null for a guest.
  final String? userId;

  static const _maxCount = 5;

  /// [results] in the order of [picks] (the server's personal ranking); a pick the loaded results do not hold is
  /// skipped.
  static List<ProviderSearchResult> personal(List<RecommendedProvider> picks, List<ProviderSearchResult> results) {
    final byId = {for (final r in results) r.id: r};
    return [for (final pick in picks) ?byId[pick.providerId]];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final picks = userId == null
        ? const <RecommendedProvider>[]
        : ref.watch(recommendedProvidersProvider(userId!)).value ?? const <RecommendedProvider>[];
    final personalized = personal(picks, results);

    final List<ProviderSearchResult> shown;
    if (personalized.isNotEmpty) {
      shown = personalized;
    } else {
      final excludedIds = excluding.map((r) => r.id).toSet();
      shown =
          results.where((r) => r.averageRating != null && !excludedIds.contains(r.id)).toList()
            ..sort((a, b) => b.averageRating!.compareTo(a.averageRating!));
    }
    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // Only claims "for you" when it really is learned from their history.
          personalized.isNotEmpty ? l10n.homeRecommendedForYouTitle : l10n.homeRecommendedTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: FactorySpacing.space3),
        for (final result in shown.take(_maxCount))
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

/// Three shortcuts under the search field: free today, closest, best rated.
/// Each opens Search already narrowed that way, so "who can take me today" is
/// one tap instead of search, filter sheet, toggle, apply. Scrolls sideways
/// rather than wrapping, so a narrow phone or a large font never grows a
/// second row.
class _QuickChips extends StatelessWidget {
  const _QuickChips();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Runs to the screen edge, like the categories: a chip cut at the page
      // padding looks broken, one that bleeds off the edge says "scroll".
      clipBehavior: Clip.none,
      child: Row(
        children: [
          FactoryChip(
            label: l10n.homeChipToday,
            icon: Symbols.event_available_rounded,
            onTap: () => context.go(AppRoutes.search(availableOnly: true)),
          ),
          const SizedBox(width: FactorySpacing.space2),
          FactoryChip(
            label: l10n.homeChipNearby,
            icon: Symbols.near_me_rounded,
            onTap: () => context.go(AppRoutes.search(sort: DiscoverySort.distance)),
          ),
          const SizedBox(width: FactorySpacing.space2),
          FactoryChip(
            label: l10n.homeChipTopRated,
            icon: Symbols.star_rounded,
            iconFilled: true,
            onTap: () => context.go(AppRoutes.search(sort: DiscoverySort.rating)),
          ),
        ],
      ),
    );
  }
}

/// The admin-run promo banners as one card under the categories. Best-effort:
/// nothing while loading, on error, or when none is live.
class _BannersSection extends ConsumerWidget {
  const _BannersSection({this.top = FactorySpacing.space5, this.height = HomeBannerCarousel.defaultHeight});

  final double top;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(homeBannersProvider).value ?? const <AdBanner>[];
    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: HomeBannerCarousel(
        height: height,
        banners: banners,
        onOpenVideo: (banner) => context.push(
          AppRoutes.adVideo,
          extra: AdVideoArgs(url: banner.videoUrl!, title: banner.title),
        ),
        onOpenLink: (target) => switch (target) {
          AdLinkTarget.rewards => context.push(AppRoutes.rewards),
          AdLinkTarget.search => context.go(AppRoutes.search()),
        },
      ),
    );
  }
}

/// "Popular services": what people book, with the lowest price, rather than
/// only who offers it. A tap opens Search for that service. The server's
/// most-booked list when it has one, else built from what the home feed already
/// loaded (see [popularServices]); absent while there is nothing to show.
class _PopularServicesSection extends ConsumerWidget {
  const _PopularServicesSection({required this.results});

  final List<ProviderSearchResult> results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // What customers really booked, when the server has that; otherwise what the most businesses nearby offer.
    final booked = ref.watch(popularServicesProvider).value ?? const <PopularService>[];
    final services = booked.isNotEmpty ? booked : popularServices(results);
    if (services.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: FactorySpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactorySectionHeader(
            title: l10n.homePopularServicesTitle,
            actionLabel: l10n.homeSeeAll,
            onActionTap: () => context.go(AppRoutes.search()),
          ),
          const SizedBox(height: FactorySpacing.space3),
          SizedBox(
            // Title (two lines), price and business count, with room for larger system text.
            height: 112 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: services.length,
              separatorBuilder: (_, _) => const SizedBox(width: FactorySpacing.space3),
              itemBuilder: (context, index) => _PopularServiceCard(
                service: services[index],
                onTap: () => context.go(AppRoutes.search(query: services[index].title)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularServiceCard extends StatelessWidget {
  const _PopularServiceCard({required this.service, required this.onTap});

  final PopularService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: FactoryRadius.mdRadius,
        onTap: onTap,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(FactorySpacing.space3),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: FactoryRadius.mdRadius,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(color: colors.text),
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: FactoryPriceText(
                  amount: service.minPrice,
                  currencySymbol: service.currency,
                  prefix: '${l10n.homePopularServiceFrom} ',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.homePopularServiceBusinesses(service.providerCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your next booking": the soonest upcoming visit under the search, for a
/// logged-in customer who has one. A tap opens Bookings. Best-effort: nothing
/// while loading, on error, or with nothing coming up.
class _NextBookingSection extends ConsumerWidget {
  const _NextBookingSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final bookings = ref.watch(myBookingsProvider(userId)).value ?? const <Booking>[];
    final now = DateTime.now();
    final next = nextBooking(bookings, now);
    if (next == null) return const SizedBox.shrink();

    final when = slotLabel(l10n, locale, now, next.startsAt!.toLocal());
    final details = [
      if (next.providerName != null) next.providerName!,
      if (next.status == 'PENDING_PAYMENT') l10n.bookingStatusPendingPayment,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: FactorySpacing.space4),
      child: FactoryCard(
        onTap: () => context.go(AppRoutes.bookings),
        padding: const EdgeInsets.all(FactorySpacing.space3),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: colors.primaryTint, borderRadius: FactoryRadius.mdRadius),
              child: Icon(Symbols.calendar_month_rounded, color: colors.primary),
            ),
            const SizedBox(width: FactorySpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeNextBookingTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                  Text(
                    next.serviceTitle == null ? when : '${next.serviceTitle} · $when',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(color: colors.text),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                ],
              ),
            ),
            Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// The reference Home's top row: who is looking and where (the city is how a person tells the app where to find
/// services, so it is one tap away), then favourites and notifications. The avatar opens Profile.
class _ReferenceHeader extends StatelessWidget {
  const _ReferenceHeader({required this.user, required this.cityLabel, required this.greeting});

  final UserSummary? user;
  final String cityLabel;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final user = this.user;
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.go(AppRoutes.profile),
          child: FactoryAvatar(
            initials: user != null ? initialsFor(user.displayName) : '?',
            image: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
          ),
        ),
        const SizedBox(width: FactorySpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(color: colors.text, fontWeight: FontWeight.w700),
              ),
              InkWell(
                onTap: () => context.push('/city-selection'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.location_on_rounded, size: 14, color: colors.primary),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          cityLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                        ),
                      ),
                      Icon(Symbols.keyboard_arrow_down_rounded, size: 16, color: colors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const _FavoritesButton(),
        if (user != null) ...[
          const SizedBox(width: FactorySpacing.space2),
          const NotificationBellButton(),
        ],
      ],
    );
  }
}

/// One row of categories, like the reference: the first four of the catalog (its own admin-curated order) and "More"
/// for the rest. A launcher, not a filter: a tap opens Search already narrowed to that category.
class _CategoriesRow extends ConsumerWidget {
  const _CategoriesRow();

  /// Four categories and "More" fit five across on a normal phone; on a narrow one or with a large font the labels
  /// would break mid-word, so it is three and "More".
  static const _roomy = 4;
  static const _tight = 3;
  static const _gap = FactorySpacing.space2;

  Future<void> _openAll(BuildContext context) async {
    final code = await context.push<String>(AppRoutes.categories);
    if (code != null && context.mounted) context.go(AppRoutes.search(category: code));
  }

  // Same height rule as the grid's tiles: the chrome plus up to two label lines at the user's text scale.
  static double _tileHeightFor(BuildContext context) =>
      72 + 2 * MediaQuery.textScalerOf(context).scale(13 * 1.2) + 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categoriesAsync = ref.watch(categoriesProvider);
    final languageCode = Localizations.localeOf(context).languageCode;
    final tileHeight = _tileHeightFor(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    // Best-effort: skeletons while the catalog loads; on error no row (the heading's link still works).
    if (categoriesAsync.hasError) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactorySectionHeader(
          title: l10n.homeCategoriesTitle,
          actionLabel: l10n.homeCategoriesAll,
          onActionTap: () => _openAll(context),
        ),
        const SizedBox(height: FactorySpacing.space3),
        LayoutBuilder(
          builder: (context, constraints) {
            final shown = constraints.maxWidth < 340 || largeText ? _tight : _roomy;
            final cells = categoriesAsync.when(
              data: (categories) => [for (final c in categories.take(shown)) (c.code, c.nameFor(languageCode))],
              loading: () => [for (var i = 0; i < shown; i++) null],
              error: (error, stackTrace) => const <(String, String)?>[],
            );
            final cell = (constraints.maxWidth - _gap * shown) / (shown + 1);
            final dense = cell < 76;
            Widget wrap(Widget child) => SizedBox(
              width: cell,
              height: tileHeight,
              // The label may use the gap beside its cell: a long word ("Образование") would break mid-word otherwise.
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxWidth: cell + _gap,
                maxHeight: tileHeight,
                child: child,
              ),
            );
            Widget tile((String, String)? entry) {
              if (entry == null) {
                return SizedBox(
                  width: cell,
                  child: FactorySkeleton(
                    width: cell,
                    height: tileHeight,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                );
              }
              final (code, label) = entry;
              final accent = colorForCategory(context, code);
              return wrap(
                FactoryCategoryTile(
                  icon: iconForCategory(code),
                  label: label,
                  labelMaxWidth: cell + _gap,
                  dense: dense,
                  accentColor: accent?.color,
                  accentTint: accent?.tint,
                  onTap: () => context.go(AppRoutes.search(category: code)),
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in cells) ...[tile(entry), const SizedBox(width: _gap)],
                if (categoriesAsync.hasValue)
                  wrap(
                    FactoryCategoryTile(
                      icon: Symbols.more_horiz_rounded,
                      label: l10n.homeCategoriesMore,
                      labelMaxWidth: cell + _gap,
                      dense: dense,
                      onTap: () => _openAll(context),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// "Top services" as a short list, like the reference: what people book most, the lowest price and how many
/// businesses offer it; a tap searches for that service. The server's most-booked list when it has one, else what
/// the loaded search results offer (see [popularServices]); absent while there is nothing to show.
class _TopServicesSection extends ConsumerWidget {
  const _TopServicesSection({required this.results});

  final List<ProviderSearchResult> results;

  static const _count = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final booked = ref.watch(popularServicesProvider).value ?? const <PopularService>[];
    final services = (booked.isNotEmpty ? booked : popularServices(results)).take(_count).toList();
    if (services.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: FactorySpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactorySectionHeader(
            title: l10n.homeTopServicesTitle,
            actionLabel: l10n.homeSeeAll,
            onActionTap: () => context.go(AppRoutes.search()),
          ),
          const SizedBox(height: FactorySpacing.space2),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: FactoryRadius.lgRadius,
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < services.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.border),
                  _TopServiceRow(
                    service: services[i],
                    onTap: () => context.go(AppRoutes.search(query: services[i].title)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopServiceRow extends StatelessWidget {
  const _TopServiceRow({required this.service, required this.onTap});

  final PopularService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final vertical = service.vertical;
    final accent = vertical == null ? null : colorForCategory(context, vertical);
    return InkWell(
      borderRadius: FactoryRadius.lgRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space3),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent?.tint ?? colors.primaryTint,
                borderRadius: FactoryRadius.mdRadius,
              ),
              child: Icon(
                vertical == null ? Symbols.sell_rounded : iconForCategory(vertical),
                size: 22,
                color: accent?.color ?? colors.primary,
              ),
            ),
            const SizedBox(width: FactorySpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FactoryPriceText(
                        amount: service.minPrice,
                        currencySymbol: service.currency,
                        prefix: '${l10n.homePopularServiceFrom} ',
                        fontSize: 12,
                      ),
                      Text(
                        ' · ${l10n.homePopularServiceBusinesses(service.providerCount)}',
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
