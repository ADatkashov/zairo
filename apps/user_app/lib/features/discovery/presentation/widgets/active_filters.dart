import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../providers/discovery_providers.dart';

/// What is narrowing the results, one removable chip per filter, right under
/// the search field. Without it a filter set a screen ago (a category tapped on
/// Home, say) silently thins the list and the person cannot tell why.
class ActiveFilters extends ConsumerWidget {
  const ActiveFilters({
    super.key,
    required this.query,
    required this.currency,
    required this.onChanged,
  });

  final DiscoveryQuery query;
  final String currency;
  final ValueChanged<DiscoveryQuery> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final categories = ref.watch(categoriesProvider).value ?? const [];

    final chips = <(String, DiscoveryQuery)>[];
    final vertical = query.vertical;
    if (vertical != null) {
      final match = categories.where((c) => c.code == vertical);
      chips.add((
        match.isEmpty ? vertical : match.first.nameFor(languageCode),
        query.copyWith(clearVertical: true),
      ));
    }
    final min = query.minPrice;
    final max = query.maxPrice;
    if (min != null || max != null) {
      String money(double value) => formatFactoryMoney(value, currency);
      chips.add((
        min != null && max != null
            ? l10n.searchFilterPriceRangeValue(money(min), money(max))
            : min != null
            ? l10n.searchActivePriceFrom(money(min))
            : l10n.searchActivePriceTo(money(max!)),
        query.copyWith(clearPriceRange: true),
      ));
    }
    if (query.maxDistanceKm != null) {
      chips.add((
        l10n.searchFilterMaxDistanceValue(query.maxDistanceKm!.round()),
        query.copyWith(clearMaxDistance: true),
      ));
    }
    if (query.minRating != null) {
      chips.add((
        l10n.searchFilterMinRatingValue(query.minRating!.toStringAsFixed(1)),
        query.copyWith(clearMinRating: true),
      ));
    }
    if (query.availableOnly) {
      chips.add((
        l10n.searchFilterAvailableOnlyLabel,
        query.copyWith(availableOnly: false),
      ));
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4),
        itemCount: chips.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: FactorySpacing.space2),
        itemBuilder: (context, index) {
          final (label, without) = chips[index];
          return ActiveFilterChip(
            label: label,
            onRemove: () => onChanged(without),
          );
        },
      ),
    );
  }
}

class ActiveFilterChip extends StatelessWidget {
  const ActiveFilterChip({super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Semantics(
        button: true,
        label: l10n.searchActiveFilterRemove(label),
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.only(
              left: FactorySpacing.space3,
              right: FactorySpacing.space2,
              top: 6,
              bottom: 6,
            ),
            decoration: BoxDecoration(
              color: colors.primaryTint,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.primary, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: colors.primaryStrong),
                ),
                const SizedBox(width: 4),
                Icon(
                  Symbols.close_rounded,
                  size: 16,
                  color: colors.primaryStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
