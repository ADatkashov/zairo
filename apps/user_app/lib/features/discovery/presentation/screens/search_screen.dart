import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/active_filters.dart';
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

/// Search — GET /api/v1/search/providers. A full-screen route above the tab
/// shell, opened by the bottom bar's "Find a service" action.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.initialVertical,
    this.initialQuery,
    this.initialAvailableOnly = false,
    this.initialSort,
    this.autofocus = false,
  });

  /// Open already narrowed to businesses with a free slot / in a given order
  /// (Home's quick chips).
  final bool initialAvailableOnly;
  final DiscoverySort? initialSort;

  /// Open with the keyboard up (the bottom bar's action), instead of on the results.
  final bool autofocus;

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
    availableOnly: widget.initialAvailableOnly,
    sort: widget.initialSort ?? DiscoverySort.recommended,
  );

  /// A new category/query for the same route (a link opened while Search is
  /// already showing) arrives here.
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
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      Padding(
                        padding: const EdgeInsets.only(right: FactorySpacing.space2),
                        child: IconButton(
                          icon: const Icon(Symbols.arrow_back_rounded),
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    Expanded(
                      child: FactorySearchField(
                  autofocus: widget.autofocus,
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
                          // The sheet pins its own header and actions around
                          // a scrolling body.
                          scrollable: false,
                          builder: (_) => _FilterSheet(initial: _query),
                        );
                    if (updated != null) {
                      setState(() => _query = updated);
                    }
                  },
                      ),
                    ),
                  ],
                ),
              ),
              if (query.hasActiveFilters)
                ActiveFilters(
                  query: query,
                  currency: resultsAsync.asData == null || resultsAsync.asData!.value.isEmpty
                      ? 'KZT'
                      : PriceBounds.fromResults(resultsAsync.asData!.value)?.currency ?? 'KZT',
                  onChanged: (updated) => setState(() => _query = updated),
                ),
              if (isPristine)
                // Never more than a third of the screen, scrolling inside: with a large font on a small phone the
                // shortcuts would otherwise squeeze the results to nothing.
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 3),
                  child: SingleChildScrollView(child: _RecentAndPopularSearches(onQuerySelected: _runSearch)),
                ),
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
  static const _collapsedCategoryCount = 8;

  late String? _vertical;

  /// Only the first few categories are chips until the person asks for the rest
  /// (22 chips pushed price and sorting off the sheet).
  bool _allCategories = false;
  late DiscoverySort _sort;
  late bool _availableOnly;
  // null = that end of the price range isn't restricted. The slider and the
  // two boxes under it are two views of these; an empty box means no limit.
  late double? _priceFrom;
  late double? _priceTo;
  late final TextEditingController _priceFromController;
  late final TextEditingController _priceToController;
  late bool _distanceEnabled;
  late double _maxDistanceKm;
  late bool _minRatingEnabled;
  late double _minRating;

  /// The draft the "Show N options" counter is computed for. Lags [_draft] on
  /// purpose while a slider is dragged or a price typed, so the sheet asks the
  /// server once the finger lifts / the typing pauses, not on every frame or
  /// keystroke.
  late DiscoveryQuery _countQuery;
  Timer? _countTimer;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _vertical = initial.vertical;
    _sort = initial.sort;
    _availableOnly = initial.availableOnly;
    _priceFrom = initial.minPrice;
    _priceTo = initial.maxPrice;
    _priceFromController = TextEditingController(text: _priceText(_priceFrom));
    _priceToController = TextEditingController(text: _priceText(_priceTo));
    _distanceEnabled = initial.maxDistanceKm != null;
    _maxDistanceKm = initial.maxDistanceKm ?? 10;
    _minRatingEnabled = initial.minRating != null;
    _minRating = initial.minRating ?? 4;
    _countQuery = _draft();
  }

  @override
  void dispose() {
    _countTimer?.cancel();
    _priceFromController.dispose();
    _priceToController.dispose();
    super.dispose();
  }

  /// What "Apply" would search for with the form as it stands now.
  DiscoveryQuery _draft() {
    // "From 9000 to 3000" is read as 3000–9000, not as an empty result.
    final swapped = _priceFrom != null && _priceTo != null && _priceFrom! > _priceTo!;
    return DiscoveryQuery(
      query: widget.initial.query,
      vertical: _vertical,
      minPrice: swapped ? _priceTo : _priceFrom,
      maxPrice: swapped ? _priceFrom : _priceTo,
      maxDistanceKm: _distanceEnabled ? _maxDistanceKm : null,
      minRating: _minRatingEnabled ? _minRating : null,
      availableOnly: _availableOnly,
      sort: _sort,
    );
  }

  static String _priceText(double? price) => price == null ? '' : price.round().toString();

  /// A price typed in one of the boxes (empty = no limit on that side).
  void _priceTyped() {
    _priceFrom = double.tryParse(_priceFromController.text.trim());
    _priceTo = double.tryParse(_priceToController.text.trim());
    _refreshCount(debounce: true);
  }

  /// Re-point the counter at the current draft — at once for a tap, after a
  /// short pause for typing.
  void _refreshCount({bool debounce = false}) {
    _countTimer?.cancel();
    if (!debounce) {
      setState(() => _countQuery = _draft());
      return;
    }
    _countTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _countQuery = _draft());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final media = MediaQuery.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      // Lift the sheet above the keyboard so a price field never hides
      // behind it; the body scrolls inside what's left.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (media.size.height - media.viewInsets.bottom) * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title + close stay on screen however long the form is.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FactorySpacing.space4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.searchFiltersTitle,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  FactoryIconButton(
                    icon: Symbols.close_rounded,
                    semanticLabel: l10n.searchFilterCloseTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FactorySpacing.space2),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: FactorySpacing.space4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _fields(context, l10n, colors),
                ),
              ),
            ),
            // The main action is always one tap away, and says what it will
            // do: how many providers the current choices match.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FactorySpacing.space4,
                FactorySpacing.space3,
                FactorySpacing.space4,
                FactorySpacing.space4,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FactoryButton(
                      label: l10n.searchFilterClearButton,
                      variant: FactoryButtonVariant.secondary,
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(DiscoveryQuery(query: widget.initial.query)),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.space3),
                  Expanded(
                    flex: 3,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final count = ref
                            .watch(searchResultsProvider(_countQuery))
                            .asData
                            ?.value
                            .length;
                        return FactoryButton(
                          label: count == null
                              ? l10n.searchFilterApplyButton
                              : l10n.searchFilterShowResults(count),
                          onPressed: () => Navigator.of(context).pop(_draft()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields(
    BuildContext context,
    AppLocalizations l10n,
    FactoryColors colors,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return [
      Text(l10n.searchFilterCategoryLabel, style: textTheme.labelLarge),
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
          // A chosen category stays visible even when it is beyond the first few.
          final shown = _allCategories
              ? categories
              : [
                  for (var i = 0; i < categories.length; i++)
                    if (i < _collapsedCategoryCount || categories[i].code == _vertical) categories[i],
                ];
          return Wrap(
            spacing: FactorySpacing.space2,
            runSpacing: FactorySpacing.space2,
            children: [
              _verticalChip(l10n.searchFilterCategoryAll, null),
              for (final category in shown)
                _verticalChip(category.nameFor(languageCode), category.code),
              if (!_allCategories && shown.length < categories.length)
                FactoryChip(
                  label: l10n.searchFilterCategoryMore,
                  icon: Symbols.expand_more_rounded,
                  onTap: () => setState(() => _allCategories = true),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: FactorySpacing.space2),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.searchFilterAvailableOnlyLabel),
        value: _availableOnly,
        onChanged: (value) {
          _availableOnly = value;
          _refreshCount();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.searchFilterMaxDistanceLabel),
        value: _distanceEnabled,
        onChanged: (value) {
          _distanceEnabled = value;
          _refreshCount();
        },
      ),
      if (_distanceEnabled) ...[
        Text(
          l10n.searchFilterMaxDistanceValue(_maxDistanceKm.round()),
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        Slider(
          value: _maxDistanceKm,
          min: 1,
          max: 50,
          divisions: 49,
          onChanged: (value) => setState(() => _maxDistanceKm = value),
          onChangeEnd: (_) => _refreshCount(),
        ),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.searchFilterMinRatingLabel),
        value: _minRatingEnabled,
        onChanged: (value) {
          _minRatingEnabled = value;
          _refreshCount();
        },
      ),
      if (_minRatingEnabled) ...[
        Text(
          l10n.searchFilterMinRatingValue(_minRating.toStringAsFixed(1)),
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        Slider(
          value: _minRating,
          min: 1,
          max: 5,
          divisions: 8,
          onChanged: (value) => setState(() => _minRating = value),
          onChangeEnd: (_) => _refreshCount(),
        ),
      ],
      const SizedBox(height: FactorySpacing.space4),
      Consumer(
        builder: (context, ref, _) {
          // The scale comes from the search itself (without the sheet's own
          // filters, so it doesn't shift while choosing). Nothing to choose
          // between → no slider, rather than a dead one; the boxes stay.
          final results = ref
              .watch(searchResultsProvider(DiscoveryQuery(query: widget.initial.query)))
              .asData
              ?.value;
          final bounds = results == null ? null : PriceBounds.fromResults(results);
          RangeValues? values;
          String from = '';
          String to = '';
          if (bounds != null) {
            // Through the draft, so a pair typed the wrong way round (9000 to
            // 5000) is ordered for the slider just as it is for the search.
            final draft = _draft();
            values = RangeValues(
              (draft.minPrice ?? bounds.min).clamp(bounds.min, bounds.max),
              (draft.maxPrice ?? bounds.max).clamp(bounds.min, bounds.max),
            );
            from = formatFactoryMoney(values.start, bounds.currency);
            to = formatFactoryMoney(values.end, bounds.currency);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A Wrap, not a Row: with a large font on a narrow phone the
              // selection drops under the title instead of overflowing.
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: FactorySpacing.space2,
                  children: [
                    Text(l10n.searchFilterPriceRangeLabel, style: textTheme.labelLarge),
                    if (bounds != null)
                      Text(
                        l10n.searchFilterPriceRangeValue(from, to),
                        style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (bounds != null && values != null)
                RangeSlider(
                  values: values,
                  min: bounds.min,
                  max: bounds.max,
                  divisions: bounds.divisions,
                  labels: RangeLabels(from, to),
                  onChanged: (range) => setState(() {
                    // An end left on its limit means "no limit" on that side.
                    _priceFrom = range.start <= bounds.min ? null : range.start;
                    _priceTo = range.end >= bounds.max ? null : range.end;
                    _priceFromController.text = _priceText(_priceFrom);
                    _priceToController.text = _priceText(_priceTo);
                  }),
                  onChangeEnd: (_) => _refreshCount(),
                )
              else
                const SizedBox(height: FactorySpacing.space2),
              // The exact amounts, typed — the slider moves to follow them.
              Row(
                children: [
                  Expanded(
                    child: FactoryTextField(
                      controller: _priceFromController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      label: l10n.searchFilterPriceMinHint,
                      hint: bounds?.min.round().toString(),
                      onChanged: (_) => setState(_priceTyped),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space2),
                    child: Text('—', style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
                  ),
                  Expanded(
                    child: FactoryTextField(
                      controller: _priceToController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      label: l10n.searchFilterPriceMaxHint,
                      hint: bounds?.max.round().toString(),
                      onChanged: (_) => setState(_priceTyped),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      const SizedBox(height: FactorySpacing.space4),
      Text(l10n.searchSortLabel, style: textTheme.labelLarge),
      const SizedBox(height: FactorySpacing.space2),
      DropdownButtonFormField<DiscoverySort>(
        initialValue: _sort,
        isExpanded: true,
        style: textTheme.bodyMedium?.copyWith(color: colors.text),
        icon: const Icon(Symbols.expand_more_rounded),
        items: [
          for (final sort in DiscoverySort.values)
            DropdownMenuItem(
              value: sort,
              child: Text(_sortLabel(l10n, sort), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value == null) return;
          _sort = value;
          _refreshCount();
        },
      ),
      const SizedBox(height: FactorySpacing.space2),
    ];
  }

  Widget _verticalChip(String label, String? value) {
    return FactoryChip(
      label: label,
      selected: _vertical == value,
      onTap: () {
        _vertical = value;
        _refreshCount();
      },
    );
  }
}
