import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../booking/presentation/screens/provider_detail_screen.dart';
import '../providers/discovery_providers.dart';
import '../widgets/provider_card.dart';

/// The Search tab — GET /api/v1/search/providers. Vertical filtering isn't
/// exposed in this UI yet (no vertical-selection UX exists beyond the
/// single "beauty" test data) even though the backend already supports it;
/// only the free-text query is wired up here.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  DiscoveryQuery _query = const DiscoveryQuery();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final query = _query;
    final resultsAsync = ref.watch(searchResultsProvider(query));

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: l10n.searchHint,
                        prefixIcon: Icon(Icons.search, color: colors.textTertiary),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        final trimmed = value.trim();
                        setState(() => _query = _query.copyWith(query: trimmed.isEmpty ? null : trimmed));
                      },
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.space2),
                  _FiltersButton(
                    active: query.hasActiveFilters || query.sort != DiscoverySort.recommended,
                    tooltip: l10n.searchFiltersButton,
                    onTap: () async {
                      final updated = await showDialog<DiscoveryQuery>(
                        context: context,
                        builder: (_) => _FilterDialog(initial: _query),
                      );
                      if (updated != null) {
                        setState(() => _query = updated);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: resultsAsync.when(
                data: (results) {
                  if (results.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(FactorySpacing.space4),
                        child: FactoryEmptyState(
                          icon: query.query == null ? Icons.search_rounded : Icons.search_off_rounded,
                          title: query.query == null
                              ? l10n.searchEmptyTitle
                              : l10n.searchEmptyTitleQuery(query.query!),
                          message: query.query == null
                              ? l10n.searchEmptyMessageDefault
                              : l10n.searchEmptyMessageQuery,
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(searchResultsProvider(query).future),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FactorySpacing.space4,
                        vertical: FactorySpacing.space2,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return ProviderCard(
                          result: result,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: result)),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(FactorySpacing.space4),
                    child: FactoryErrorState(
                      message: l10n.errorSearchLoadFailed,
                      onRetry: () => ref.invalidate(searchResultsProvider(query)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain IconButton wouldn't show whether a filter is currently active —
/// this fills that gap with a small dot, same "state must be visible, not
/// just present" idea as FactoryBadge elsewhere in this design system.
class _FiltersButton extends StatelessWidget {
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _FiltersButton({required this.active, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton.outlined(
            onPressed: onTap,
            icon: Icon(Icons.tune_rounded, color: active ? colors.primary : colors.textSecondary),
            style: IconButton.styleFrom(
              side: BorderSide(color: active ? colors.primary : colors.border, width: 1.5),
            ),
          ),
          if (active)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final DiscoveryQuery initial;

  const _FilterDialog({required this.initial});

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
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
    _sort = initial.sort;
    _availableOnly = initial.availableOnly;
    _minPriceController = TextEditingController(text: initial.minPrice?.toStringAsFixed(0) ?? '');
    _maxPriceController = TextEditingController(text: initial.maxPrice?.toStringAsFixed(0) ?? '');
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

    return AlertDialog(
      title: Text(l10n.searchFiltersTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.searchSortLabel, style: Theme.of(context).textTheme.labelLarge),
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
            Text(l10n.searchFilterPriceRangeLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: FactorySpacing.space2),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: l10n.searchFilterPriceMinHint),
                  ),
                ),
                const SizedBox(width: FactorySpacing.space2),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: l10n.searchFilterPriceMaxHint),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              Slider(
                value: _minRating,
                min: 1,
                max: 5,
                divisions: 8,
                onChanged: (value) => setState(() => _minRating = value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(DiscoveryQuery(query: widget.initial.query)),
          child: Text(l10n.searchFilterClearButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            DiscoveryQuery(
              query: widget.initial.query,
              minPrice: double.tryParse(_minPriceController.text.trim()),
              maxPrice: double.tryParse(_maxPriceController.text.trim()),
              maxDistanceKm: _distanceEnabled ? _maxDistanceKm : null,
              minRating: _minRatingEnabled ? _minRating : null,
              availableOnly: _availableOnly,
              sort: _sort,
            ),
          ),
          child: Text(l10n.searchFilterApplyButton),
        ),
      ],
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
