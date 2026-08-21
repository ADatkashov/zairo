import 'package:core_ui/core_ui.dart' hide ProviderCard;
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
  String? _query;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final query = DiscoveryQuery(query: _query);
    final resultsAsync = ref.watch(searchResultsProvider(query));

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(FactorySpacing.space4),
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
                  setState(() => _query = trimmed.isEmpty ? null : trimmed);
                },
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
                          icon: _query == null ? Icons.search_rounded : Icons.search_off_rounded,
                          title: _query == null ? l10n.searchEmptyTitle : l10n.searchEmptyTitleQuery(_query!),
                          message: _query == null ? l10n.searchEmptyMessageDefault : l10n.searchEmptyMessageQuery,
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
