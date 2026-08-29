import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../booking/data/models/book_again_suggestion.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../../booking/presentation/screens/provider_detail_screen.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../maps/presentation/providers/maps_providers.dart';
import '../../data/models/provider_search_result.dart';
import '../../data/models/service_summary.dart';
import '../providers/discovery_providers.dart';
import '../widgets/provider_card.dart';

/// Icons aren't part of the master catalog (a presentation detail, not
/// taxonomy) — this is a small, forward-compatible local lookup, not a
/// hardcoded `if (category == "beauty")` business-logic branch: unknown
/// codes still render, just with a generic icon, instead of failing.
IconData _iconForCategory(String code) => switch (code) {
  'beauty' => Icons.content_cut_rounded,
  'auto' => Icons.directions_car_filled_rounded,
  'cleaning' => Icons.cleaning_services_rounded,
  _ => Icons.storefront_outlined,
};

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
    final user = ref.watch(authControllerProvider).valueOrNull;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: resultsAsync.when(
          data: (results) {
            final openCount = results.where((r) => r.hasOpenAvailability).length;
            final topRated = results.take(8).toList();
            return RefreshIndicator(
              onRefresh: () => ref.refresh(searchResultsProvider(query).future),
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(locationAsync.valueOrNull?.label ?? l10n.homeLocationUnknown, style: textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.space1),
                  Text(
                    user != null ? l10n.homeGreeting(user.displayName) : l10n.homeGreetingGuest,
                    style: textTheme.headlineSmall?.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: FactorySpacing.space4),
                  _SearchEntry(onTap: () => context.go('/search')),
                  const SizedBox(height: FactorySpacing.space4),
                  Text(l10n.homeCategoriesTitle, style: textTheme.titleSmall),
                  const SizedBox(height: FactorySpacing.space3),
                  _CategoryRow(
                    selectedCode: _vertical,
                    onSelect: (code) => setState(() => _vertical = code),
                  ),
                  if (openCount > 0) ...[
                    const SizedBox(height: FactorySpacing.space5),
                    _AvailabilityHero(count: openCount),
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
                      icon: Icons.storefront_outlined,
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
                        separatorBuilder: (_, _) => const SizedBox(width: FactorySpacing.space3),
                        itemBuilder: (context, index) {
                          final result = topRated[index];
                          return ProviderCard(
                            result: result,
                            layout: FactoryProviderCardLayout.vertical,
                            width: 168,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: result)),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
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
        borderRadius: FactoryRadius.mdRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space3),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: FactoryRadius.mdRadius,
            border: Border.all(color: colors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: colors.textTertiary),
              const SizedBox(width: 10),
              Text(
                l10n.homeSearchPrompt,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.selectedCode, required this.onSelect});

  final String? selectedCode;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categoriesAsync = ref.watch(categoriesProvider);
    final languageCode = Localizations.localeOf(context).languageCode;

    return categoriesAsync.when(
      data: (categories) => Row(
        children: [
          FactoryCategoryTile(
            icon: Icons.apps_rounded,
            label: l10n.searchFilterCategoryAll,
            selected: selectedCode == null,
            onTap: () => onSelect(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: FactorySpacing.space3),
            FactoryCategoryTile(
              icon: _iconForCategory(category.code),
              label: category.nameFor(languageCode),
              selected: selectedCode == category.code,
              onTap: () => onSelect(category.code),
            ),
          ],
        ],
      ),
      // Best-effort: while loading or on error, still show the "All" tile
      // (search already works with vertical: null) rather than blocking
      // the whole Home screen on the catalog request.
      loading: () => Row(
        children: [
          FactoryCategoryTile(
            icon: Icons.apps_rounded,
            label: l10n.searchFilterCategoryAll,
            selected: selectedCode == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: FactorySpacing.space3),
          const FactorySkeleton(width: 64, height: 84, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(width: FactorySpacing.space3),
          const FactorySkeleton(width: 64, height: 84, borderRadius: BorderRadius.all(Radius.circular(12))),
        ],
      ),
      error: (error, stackTrace) => Row(
        children: [
          FactoryCategoryTile(
            icon: Icons.apps_rounded,
            label: l10n.searchFilterCategoryAll,
            selected: selectedCode == null,
            onTap: () => onSelect(null),
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
    final suggestions = suggestionsAsync.valueOrNull ?? const [];
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.homeBookAgainTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: FactorySpacing.space3),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: FactorySpacing.space3),
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.text),
              ),
              const SizedBox(height: 2),
              Text(
                suggestion.serviceTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              const Spacer(),
              FactoryPriceText(amount: suggestion.price, currencySymbol: suggestion.currency),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityHero extends StatelessWidget {
  const _AvailabilityHero({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FactorySpacing.space4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryStrong, colors.primary],
        ),
        borderRadius: FactoryRadius.lgRadius,
      ),
      child: Text(
        AppLocalizations.of(context)!.homeAvailabilityHero(count),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.onPrimary),
      ),
    );
  }
}
