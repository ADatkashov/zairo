import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../booking/presentation/screens/provider_detail_screen.dart';
import '../providers/discovery_providers.dart';
import '../widgets/provider_card.dart';

/// Browse/search providers — GET /api/v1/search/providers. Vertical
/// filtering isn't exposed in this UI yet (no vertical-selection UX exists
/// beyond the single "beauty" test data) even though the backend already
/// supports it; only the free-text query is wired up here.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _searchController = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = DiscoveryQuery(query: _query);
    final resultsAsync = ref.watch(searchResultsProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search services or providers',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                  return const Center(child: Text('No providers found'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(searchResultsProvider(query).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: results.length,
                    itemBuilder: (context, index) => ProviderCard(
                      result: results[index],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProviderDetailScreen(provider: results[index]),
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load providers: $error'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
