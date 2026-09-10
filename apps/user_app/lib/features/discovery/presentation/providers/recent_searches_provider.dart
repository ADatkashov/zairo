import 'dart:convert';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _recentSearchesStorageKey = 'recent_search_queries';

/// Capped short — this is a quick-access shortcut list on Search, not a
/// full history log.
const _maxRecentSearches = 8;

/// Locally-persisted search history — most recent first, deduplicated
/// case-insensitively (searching "Massage" again just moves the existing
/// entry to the top rather than adding a near-duplicate). Stored via
/// SecureStorageService only because it's the storage abstraction already
/// wired into this app (auth tokens, LocaleController) — a search query
/// isn't sensitive, same reasoning as LocaleController's own doc comment.
final recentSearchesProvider = AsyncNotifierProvider<RecentSearchesController, List<String>>(
  RecentSearchesController.new,
);

class RecentSearchesController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final stored = await ref.read(secureStorageServiceProvider).read(_recentSearchesStorageKey);
    if (stored == null || stored.isEmpty) return const [];
    return (jsonDecode(stored) as List<dynamic>).cast<String>();
  }

  Future<void> addSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? const [];
    final reordered = [trimmed, ...current.where((q) => q.toLowerCase() != trimmed.toLowerCase())];
    final capped = reordered.take(_maxRecentSearches).toList();
    state = AsyncData(capped);
    await ref.read(secureStorageServiceProvider).write(_recentSearchesStorageKey, jsonEncode(capped));
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    await ref.read(secureStorageServiceProvider).delete(_recentSearchesStorageKey);
  }
}
