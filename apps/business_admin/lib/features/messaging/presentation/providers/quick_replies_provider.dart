import 'dart:convert';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _quickRepliesStorageKey = 'chat_quick_replies';

/// How many ready sentences the chat offers.
const quickReplyCount = 3;

/// The owner's own ready sentences for the chat; null means "the built-in ones". Kept on this device (like the theme
/// and the language): a business that answers the same questions all day writes them once.
final quickRepliesProvider =
    AsyncNotifierProvider<QuickRepliesController, List<String>?>(
      QuickRepliesController.new,
    );

class QuickRepliesController extends AsyncNotifier<List<String>?> {
  @override
  Future<List<String>?> build() async {
    final stored = await ref
        .read(secureStorageServiceProvider)
        .read(_quickRepliesStorageKey);
    if (stored == null) return null;
    try {
      final decoded = (jsonDecode(stored) as List<dynamic>)
          .whereType<String>()
          .toList();
      return decoded.isEmpty ? null : decoded;
    } catch (_) {
      return null; // A damaged value is the same as none: fall back to the built-in sentences.
    }
  }

  /// Saves the non-empty [replies] (at most [quickReplyCount]); nothing left means the built-in sentences again.
  Future<void> save(List<String> replies) async {
    final cleaned = [
      for (final reply in replies)
        if (reply.trim().isNotEmpty) reply.trim(),
    ].take(quickReplyCount).toList();
    if (cleaned.isEmpty) return reset();
    state = AsyncData(cleaned);
    await ref
        .read(secureStorageServiceProvider)
        .write(_quickRepliesStorageKey, jsonEncode(cleaned));
  }

  Future<void> reset() async {
    state = const AsyncData(null);
    await ref
        .read(secureStorageServiceProvider)
        .delete(_quickRepliesStorageKey);
  }
}
