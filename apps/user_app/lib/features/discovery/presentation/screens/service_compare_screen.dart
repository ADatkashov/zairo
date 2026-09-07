import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../booking/presentation/screens/provider_detail_screen.dart';
import '../providers/discovery_providers.dart';
import '../widgets/provider_card.dart';

/// "Who offers Manicure" — every business with an active offering linked to
/// one catalog.CatalogService, ranked the same deterministic way as the
/// main Search tab (see SearchService.search's RECOMMENDED default).
/// Reuses ProviderCard/FactoryEmptyState/FactoryErrorState wholesale — this
/// screen adds no new visual vocabulary, just a fixed filter.
class ServiceCompareScreen extends ConsumerWidget {
  const ServiceCompareScreen({
    super.key,
    required this.catalogServiceId,
    required this.serviceName,
  });

  final String catalogServiceId;
  final String serviceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final resultsAsync = ref.watch(
      serviceCompareResultsProvider(catalogServiceId),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: serviceName),
      body: resultsAsync.when(
        data: (results) {
          if (results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                child: FactoryEmptyState(
                  icon: Symbols.storefront_rounded,
                  title: l10n.serviceCompareEmptyTitle,
                  message: l10n.serviceCompareEmptyMessage,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            itemCount: results.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) {
              final result = results[index];
              return ProviderCard(
                result: result,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderDetailScreen(provider: result),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorSearchLoadFailed,
              onRetry: () => ref.invalidate(
                serviceCompareResultsProvider(catalogServiceId),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
