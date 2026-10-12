import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import '../../../../core/provider_grid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../data/models/provider_search_result.dart';
import '../providers/discovery_providers.dart';
import '../providers/recent_searches_provider.dart';
import '../widgets/provider_card.dart';

/// A small, fixed shortlist — not sourced from the catalog or any
/// "trending now" telemetry (neither exists yet), just common queries
/// spanning more than one vertical so it doesn't read as beauty-only.
List<String> _popularSearches(AppLocalizations l10n) => [
  l10n.searchPopularQueryHaircut,
  l10n.searchPopularQueryManicure,
  l10n.searchPopularQueryMassage,
  l10n.searchPopularQueryOilChange,
  l10n.searchPopularQueryTireFitting,
  l10n.searchPopularQueryHomeCleaning,
];

/// The Search tab — GET /api/v1/search/providers.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialVertical, this.initialQuery});

  /// Category / text carried in from Home (`/search?category=…&q=…`), so
  /// "see all" and the search entry keep what the user had just picked.
  final String? initialVertical;
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialQuery,
  );
  late DiscoveryQuery _query = DiscoveryQuery(
    vertical: widget.initialVertical,
    query: widget.initialQuery,
  );

  /// The tab lives in an IndexedStack, so this State outlives navigations
  /// back to `/search`: a new category/query from Home arrives here.
  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialVertical != oldWidget.initialVertical) {
      setState(
        () => _query = widget.initialVertical == null
            ? _query.copyWith(clearVertical: true)
            : _query.copyWith(vertical: widget.initialVertical),
      );
    }
    if (widget.initialQuery != oldWidget.initialQuery) {
      _runSearch(widget.initialQuery ?? '');
    }
  }

  void _resetAll() {
    _searchController.clear();
    setState(() => _query = const DiscoveryQuery());
  }

  Timer? _typingTimer;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Search-as-you-type: the results follow the text once the user pauses for
  /// a moment (and from two characters on), without waiting for the keyboard's
  /// search key. Unlike [_runSearch] this does not add the text to recent
  /// searches — half-typed words would drown the list; submit / chips do that.
  void _onTyping(String value) {
    _typingTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.length == 1) return;
    _typingTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(
        () => _query = trimmed.isEmpty
            ? _query.copyWith(clearQuery: true)
            : _query.copyWith(query: trimmed),
      );
    });
  }

  bool get _filterActive =>
      _query.hasActiveFilters || _query.sort != DiscoverySort.recommended;

  /// Shared by the search field's onSubmitted and every recent/popular
  /// query chip — typing "massage" and tapping the "Massage" chip both end
  /// up in the same place: the field reflects it, the search runs, and it
  /// (re)joins recent searches at the top.
  void _runSearch(String value) {
    _typingTimer?.cancel();
    final trimmed = value.trim();
    _searchController.text = trimmed;
    setState(
      () => _query = trimmed.isEmpty
          ? _query.copyWith(clearQuery: true)
          : _query.copyWith(query: trimmed),
    );
    if (trimmed.isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).addSearch(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final query = _query;
    // Pristine: nothing typed yet and no filter/sort applied. Watching
    // searchResultsProvider unconditionally below still fires the same
    // "everything" request this screen has always made on open — this only
    // changes what's *shown* while that's pristine, swapping the results
    // list for recent/popular search shortcuts instead of an unfiltered
    // provider directory.
    final isPristine = query.query == null && !_filterActive;
    final resultsAsync = ref.watch(searchResultsProvider(query));

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: FactoryPageWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                child: FactorySearchField(
                  controller: _searchController,
                  hint: l10n.searchHint,
                  onChanged: _onTyping,
                  onSubmitted: _runSearch,
                  onCleared: () => _runSearch(''),
                  clearSemanticLabel: l10n.searchClearButton,
                  filterSemanticLabel: l10n.searchFiltersButton,
                  filterActive: _filterActive,
                  onFilterTap: () async {
                    final updated =
                        await showFactoryBottomSheet<DiscoveryQuery>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _FilterSheet(initial: _query),
                        );
                    if (updated != null) {
                      setState(() => _query = updated);
                    }
                  },
                ),
              ),
              if (isPristine)
                _RecentAndPopularSearches(onQuerySelected: _runSearch),
              Expanded(
                child: resultsAsync.when(
                  data: (results) {
                    if (results.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(FactorySpacing.space4),
                          child: FactoryEmptyState(
                            icon: query.query == null
                                ? Symbols.search_rounded
                                : Symbols.search_off_rounded,
                            title: query.query == null
                                ? l10n.searchEmptyTitle
                                : l10n.searchEmptyTitleQuery(query.query!),
                            message: query.query == null
                                ? l10n.searchEmptyMessageDefault
                                : l10n.searchEmptyMessageQuery,
                            actionLabel: query.query != null || _filterActive
                                ? l10n.searchResetFilters
                                : null,
                            onAction: _resetAll,
                          ),
                        ),
                      );
                    }
                    final columns = switch (FactoryBreakpoints.of(context)) {
                      FactoryScreenSize.mobile => 1,
                      FactoryScreenSize.tablet => 2,
                      FactoryScreenSize.desktop => 3,
                    };
                    void openProvider(ProviderSearchResult result) => context
                        .push(AppRoutes.provider(result.id), extra: result);
                    void bookProvider(ProviderSearchResult result) => context
                        .push(AppRoutes.provider(result.id, book: true), extra: result);

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            FactorySpacing.space4,
                            FactorySpacing.space2,
                            FactorySpacing.space4,
                            0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.searchResultsCount(results.length),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: colors.textTertiary),
                                ),
                              ),
                              Flexible(
                                child: _SortMenuButton(
                                  value: query.sort,
                                  onChanged: (sort) => setState(
                                    () => _query = _query.copyWith(sort: sort),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () => ref.refresh(
                              searchResultsProvider(query).future,
                            ),
                            child: columns == 1
                                ? ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: FactorySpacing.space4,
                                      vertical: FactorySpacing.space2,
                                    ),
                                    itemCount: results.length,
                                    separatorBuilder: (_, _) => const SizedBox(
                                      height: FactorySpacing.space3,
                                    ),
                                    itemBuilder: (context, index) {
                                      final result = results[index];
                                      return ProviderCard(
                                        result: result,
                                        onTap: () => openProvider(result),
                                        onBook: () => bookProvider(result),
                                      );
                                    },
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(
                                      FactorySpacing.space4,
                                    ),
                                    gridDelegate: providerGridDelegate(
                                      context,
                                      crossAxisCount: columns,
                                      spacing: FactorySpacing.space4,
                                      // Room for the "Book" button under each card.
                                      actionHeight: providerCardActionHeight,
                                    ),
                                    itemCount: results.length,
                                    itemBuilder: (context, index) {
                                      final result = results[index];
                                      return ProviderCard(
                                        result: result,
                                        layout:
                                            FactoryProviderCardLayout.vertical,
                                        onTap: () => openProvider(result),
                                        onBook: () => bookProvider(result),
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
                        message: l10n.errorSearchLoadFailed,
                        onRetry: () =>
                            ref.invalidate(searchResultsProvider(query)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact strip above the results — not instead of them: this screen has
/// always shown whatever matches the current (possibly empty) filters
/// immediately, and that stays true. This only adds recent searches (if
/// any) plus a fixed popular-queries shortlist above that, while the field
/// is empty and no filter is applied, so Search opens with something to
/// tap on top of what it already showed. Recent searches are best-effort:
/// SecureStorageService failing to load them (or simply not being
/// overridden, e.g. in a widget test) just means an empty list, not an
/// error state — the popular row alone is still a complete strip.
class _RecentAndPopularSearches extends ConsumerWidget {
  const _RecentAndPopularSearches({required this.onQuerySelected});

  final ValueChanged<String> onQuerySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final recent = ref.watch(recentSearchesProvider).value ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FactorySpacing.space4,
        0,
        FactorySpacing.space4,
        FactorySpacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recent.isNotEmpty) ...[
            FactorySectionHeader(
              title: l10n.searchRecentTitle,
              actionLabel: l10n.searchRecentClearButton,
              onActionTap: () =>
                  ref.read(recentSearchesProvider.notifier).clear(),
            ),
            const SizedBox(height: FactorySpacing.space2),
            Wrap(
              spacing: FactorySpacing.space2,
              runSpacing: FactorySpacing.space2,
              children: [
                for (final query in recent)
                  FactoryChip(
                    label: query,
                    onTap: () => onQuerySelected(query),
                  ),
              ],
            ),
            const SizedBox(height: FactorySpacing.space5),
          ],
          Text(
            l10n.searchPopularTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: FactorySpacing.space2),
          Wrap(
            spacing: FactorySpacing.space2,
            runSpacing: FactorySpacing.space2,
            children: [
              for (final query in _popularSearches(l10n))
                FactoryChip(
                  label: query,
                  icon: Symbols.trending_up_rounded,
                  onTap: () => onQuerySelected(query),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Board 07 (v2 design audit) — sort previously lived only inside the
/// filter sheet, several taps deep; this is the same [DiscoverySort]/
/// [DiscoveryQuery] plumbing the filter sheet already used, just also
/// reachable as a one-tap control above the results list.
class _SortMenuButton extends StatelessWidget {
  final DiscoverySort value;
  final ValueChanged<DiscoverySort> onChanged;

  const _SortMenuButton({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return PopupMenuButton<DiscoverySort>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final sort in DiscoverySort.values)
          PopupMenuItem(value: sort, child: Text(_sortLabel(l10n, sort))),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              l10n.searchSortButtonLabel(_sortLabel(l10n, value)),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: colors.primary),
            ),
          ),
          Icon(Symbols.expand_more_rounded, size: 18, color: colors.primary),
        ],
      ),
    );
  }
}

String _sortLabel(AppLocalizations l10n, DiscoverySort sort) => switch (sort) {
  DiscoverySort.recommended => l10n.searchSortRecommended,
  DiscoverySort.priceAsc => l10n.searchSortPriceAsc,
  DiscoverySort.priceDesc => l10n.searchSortPriceDesc,
  DiscoverySort.distance => l10n.searchSortDistance,
  DiscoverySort.rating => l10n.searchSortRating,
};

/// The filter form — presented as a bottom sheet (see [showFactoryBottomSheet]
/// in build()), matching the design system's rule that filters live in a
/// FilterSheet on mobile/tablet, not a centered dialog.
class _FilterSheet extends StatefulWidget {
  final DiscoveryQuery initial;

  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _vertical;
  late DiscoverySort _sort;
  late bool _availableOnly;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  late bool _distanceEnabled;
  late double _maxDistanceKm;
  late bool _minRatingEnabled;
  late double _minRating;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _vertical = initial.vertical;
    _sort = initial.sort;
    _availableOnly = initial.availableOnly;
    _minPriceController = TextEditingController(
      text: initial.minPrice?.toStringAsFixed(0) ?? '',
    );
    _maxPriceController = TextEditingController(
      text: initial.maxPrice?.toStringAsFixed(0) ?? '',
    );
    _distanceEnabled = initial.maxDistanceKm != null;
    _maxDistanceKm = initial.maxDistanceKm ?? 10;
    _minRatingEnabled = initial.minRating != null;
    _minRating = initial.minRating ?? 4;
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FactorySpacing.space4,
        0,
        FactorySpacing.space4,
        FactorySpacing.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.searchFiltersTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: FactorySpacing.space4),
          Text(
            l10n.searchFilterCategoryLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: FactorySpacing.space2),
          Consumer(
            builder: (context, ref, _) {
              final categoriesAsync = ref.watch(categoriesProvider);
              final languageCode = Localizations.localeOf(context).languageCode;
              // Board 07 (v2 design audit) — this used to hardcode exactly
              // the three verticals that existed when this screen was first
              // built (beauty/auto/cleaning), so a platform admin adding a
              // new category — or deactivating an old one — never showed up
              // here. Sourced from the same master catalog Home's category
              // grid already reads, ACTIVE-only by construction (see
              // CatalogController).
              final categories = categoriesAsync.value ?? const [];
              return Wrap(
                spacing: FactorySpacing.space2,
                runSpacing: FactorySpacing.space2,
                children: [
                  _verticalChip(l10n.searchFilterCategoryAll, null),
                  for (final category in categories)
                    _verticalChip(
                      category.nameFor(languageCode),
                      category.code,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: FactorySpacing.space4),
          Text(
            l10n.searchSortLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: FactorySpacing.space2),
          Wrap(
            spacing: FactorySpacing.space2,
            runSpacing: FactorySpacing.space2,
            children: [
              _sortChip(l10n.searchSortRecommended, DiscoverySort.recommended),
              _sortChip(l10n.searchSortPriceAsc, DiscoverySort.priceAsc),
              _sortChip(l10n.searchSortPriceDesc, DiscoverySort.priceDesc),
              _sortChip(l10n.searchSortDistance, DiscoverySort.distance),
              _sortChip(l10n.searchSortRating, DiscoverySort.rating),
            ],
          ),
          const SizedBox(height: FactorySpacing.space4),
          Text(
            l10n.searchFilterPriceRangeLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: FactorySpacing.space2),
          Row(
            children: [
              Expanded(
                child: FactoryTextField(
                  controller: _minPriceController,
                  keyboardType: TextInputType.number,
                  label: l10n.searchFilterPriceMinHint,
                ),
              ),
              const SizedBox(width: FactorySpacing.space2),
              Expanded(
                child: FactoryTextField(
                  controller: _maxPriceController,
                  keyboardType: TextInputType.number,
                  label: l10n.searchFilterPriceMaxHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space2),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.searchFilterAvailableOnlyLabel),
            value: _availableOnly,
            onChanged: (value) => setState(() => _availableOnly = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.searchFilterMaxDistanceLabel),
            value: _distanceEnabled,
            onChanged: (value) => setState(() => _distanceEnabled = value),
          ),
          if (_distanceEnabled) ...[
            Text(
              l10n.searchFilterMaxDistanceValue(_maxDistanceKm.round()),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            Slider(
              value: _maxDistanceKm,
              min: 1,
              max: 50,
              divisions: 49,
              onChanged: (value) => setState(() => _maxDistanceKm = value),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.searchFilterMinRatingLabel),
            value: _minRatingEnabled,
            onChanged: (value) => setState(() => _minRatingEnabled = value),
          ),
          if (_minRatingEnabled) ...[
            Text(
              l10n.searchFilterMinRatingValue(_minRating.toStringAsFixed(1)),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            Slider(
              value: _minRating,
              min: 1,
              max: 5,
              divisions: 8,
              onChanged: (value) => setState(() => _minRating = value),
            ),
          ],
          const SizedBox(height: FactorySpacing.space4),
          Row(
            children: [
              Expanded(
                child: FactoryButton(
                  label: l10n.searchFilterClearButton,
                  variant: FactoryButtonVariant.secondary,
                  onPressed: () =>
                      Navigator.of(context)
                          .pop(DiscoveryQuery(query: widget.initial.query)),
                ),
              ),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: FactoryButton(
                  label: l10n.searchFilterApplyButton,
                  onPressed: () => Navigator.of(context).pop(
                    DiscoveryQuery(
                      query: widget.initial.query,
                      vertical: _vertical,
                      minPrice: double.tryParse(
                        _minPriceController.text.trim(),
                      ),
                      maxPrice: double.tryParse(
                        _maxPriceController.text.trim(),
                      ),
                      maxDistanceKm: _distanceEnabled ? _maxDistanceKm : null,
                      minRating: _minRatingEnabled ? _minRating : null,
                      availableOnly: _availableOnly,
                      sort: _sort,
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

  Widget _verticalChip(String label, String? value) {
    return FactoryChip(
      label: label,
      selected: _vertical == value,
      onTap: () => setState(() => _vertical = value),
    );
  }

  Widget _sortChip(String label, DiscoverySort value) {
    return FactoryChip(
      label: label,
      selected: _sort == value,
      onTap: () => setState(() => _sort = value),
    );
  }
}
