import 'dart:convert';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _savedViewsKey = 'businesses_saved_views';

/// How many views a person can keep; the row of chips stays one line or two.
const int maxSavedViews = 8;

/// A named combination of the businesses list's status filter and search text.
class SavedView {
  const SavedView({required this.name, this.status, this.query = ''});

  final String name;

  /// PENDING / ACTIVE / SUSPENDED, or null for every status.
  final String? status;
  final String query;

  Map<String, Object?> toJson() => {'name': name, 'status': status, 'query': query};

  factory SavedView.fromJson(Map<String, dynamic> json) =>
      SavedView(name: json['name'] as String, status: json['status'] as String?, query: (json['query'] as String?) ?? '');

  bool matches(String? status, String query) => this.status == status && this.query == query.trim();
}

/// The saved views, kept on this device (not per account: the console runs
/// on a staff member's own machine) and restored after a restart.
final savedViewsProvider = AsyncNotifierProvider<SavedViewsController, List<SavedView>>(SavedViewsController.new);

class SavedViewsController extends AsyncNotifier<List<SavedView>> {
  @override
  Future<List<SavedView>> build() async {
    final raw = await ref.read(secureStorageServiceProvider).read(_savedViewsKey);
    if (raw == null) return const [];
    try {
      return [for (final e in jsonDecode(raw) as List<dynamic>) SavedView.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      // A damaged value is the same as no saved views.
      return const [];
    }
  }

  /// Adds [view]; a view with the same name is replaced. Returns false when
  /// the limit is reached.
  Future<bool> add(SavedView view) async {
    final current = [...?state.value];
    final without = current.where((v) => v.name != view.name).toList();
    if (without.length >= maxSavedViews) return false;
    await _save([...without, view]);
    return true;
  }

  Future<void> remove(String name) async {
    await _save([...?state.value].where((v) => v.name != name).toList());
  }

  Future<void> _save(List<SavedView> views) async {
    state = AsyncData(views);
    await ref.read(secureStorageServiceProvider).write(_savedViewsKey, jsonEncode([for (final v in views) v.toJson()]));
  }
}
