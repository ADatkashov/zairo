import 'dart:async';
import 'dart:convert';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../salon/presentation/providers/salon_providers.dart';
import 'messaging_providers.dart';

const _storageKey = 'admin_messages_seen_v1';

/// When the owner last had each conversation open (keyed by conversationId).
///
/// The backend keeps no read receipts on purpose, so "new messages" is worked
/// out on this device: a conversation is new while its last message is later
/// than the last time its thread was open here. [baseline] is the first time
/// this ran, so the conversations that already existed are not all "new".
class MessageSeen {
  const MessageSeen({required this.baseline, this.seen = const {}});

  final DateTime baseline;
  final Map<String, DateTime> seen;

  bool isNew(String conversationId, DateTime lastMessageAt) {
    final since = seen[conversationId];
    final cutoff = since != null && since.isAfter(baseline) ? since : baseline;
    return lastMessageAt.isAfter(cutoff);
  }

  Map<String, dynamic> toJson() => {
    'baseline': baseline.toIso8601String(),
    'seen': {for (final e in seen.entries) e.key: e.value.toIso8601String()},
  };

  factory MessageSeen.fromJson(Map<String, dynamic> json) => MessageSeen(
    baseline: DateTime.parse(json['baseline'] as String),
    seen: {
      for (final e in (json['seen'] as Map<String, dynamic>).entries)
        e.key: DateTime.parse(e.value as String),
    },
  );
}

final messageSeenProvider =
    AsyncNotifierProvider<MessageSeenController, MessageSeen>(
      MessageSeenController.new,
    );

class MessageSeenController extends AsyncNotifier<MessageSeen> {
  @override
  Future<MessageSeen> build() async {
    try {
      final stored = await ref
          .read(secureStorageServiceProvider)
          .read(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        return MessageSeen.fromJson(jsonDecode(stored) as Map<String, dynamic>);
      }
    } catch (_) {
      // Unreadable: start over from now.
    }
    final fresh = MessageSeen(baseline: DateTime.now().toUtc());
    unawaited(_persist(fresh));
    return fresh;
  }

  /// The thread [conversationId] was on screen and showed messages up to [at].
  Future<void> markSeen(String conversationId, DateTime at) async {
    final current = await future;
    final previous = current.seen[conversationId];
    if (previous != null && !at.isAfter(previous)) return;
    final next = MessageSeen(
      baseline: current.baseline,
      seen: {...current.seen, conversationId: at.toUtc()},
    );
    state = AsyncData(next);
    await _persist(next);
  }

  Future<void> _persist(MessageSeen value) async {
    try {
      await ref
          .read(secureStorageServiceProvider)
          .write(_storageKey, jsonEncode(value.toJson()));
    } catch (_) {
      // Best-effort: worst case the count is recomputed from the baseline.
    }
  }
}

/// New conversations across every business this owner runs. Re-checks the
/// inboxes every couple of minutes while something is watching it (the
/// Messages tab / sidebar item is).
final newMessagesCountProvider = Provider.autoDispose.family<int, String>((
  ref,
  ownerUserId,
) {
  final providers = ref.watch(myProvidersProvider(ownerUserId)).value;
  final seen = ref.watch(messageSeenProvider).value;
  if (providers == null || seen == null) return 0;

  final timer = Timer.periodic(const Duration(minutes: 2), (_) {
    for (final provider in providers) {
      ref.invalidate(providerInboxProvider(provider.id));
    }
  });
  ref.onDispose(timer.cancel);

  var count = 0;
  for (final provider in providers) {
    final conversations =
        ref.watch(providerInboxProvider(provider.id)).value ?? const [];
    count += conversations
        .where((c) => seen.isNew(c.id, c.lastMessageAt))
        .length;
  }
  return count;
});
