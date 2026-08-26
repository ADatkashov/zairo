import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../booking/presentation/screens/provider_detail_screen.dart';
import '../../../maps/presentation/providers/maps_providers.dart';
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
  /// null = every vertical. Only two real values exist today (`beauty`,
  /// `auto`) — this mirrors Search's own filter sheet rather than inventing
  /// a category taxonomy the backend doesn't have.
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
                  Wrap(
                    spacing: FactorySpacing.space2,
                    runSpacing: FactorySpacing.space2,
                    children: [
                      FactoryChip(
                        label: l10n.searchFilterCategoryAll,
                        selected: _vertical == null,
                        onTap: () => setState(() => _vertical = null),
                      ),
                      FactoryChip(
                        label: l10n.discoveryVerticalBeauty,
                        selected: _vertical == 'beauty',
                        onTap: () => setState(() => _vertical = 'beauty'),
                      ),
                      FactoryChip(
                        label: l10n.discoveryVerticalAuto,
                        selected: _vertical == 'auto',
                        onTap: () => setState(() => _vertical = 'auto'),
                      ),
                    ],
                  ),
                  if (openCount > 0) ...[
                    const SizedBox(height: FactorySpacing.space5),
                    _AvailabilityHero(count: openCount),
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
