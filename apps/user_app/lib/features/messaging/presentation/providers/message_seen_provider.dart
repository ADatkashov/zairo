import 'dart:async';
import 'dart:convert';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import 'messaging_providers.dart';

const _storageKey = 'messages_seen_v1';

/// When the customer last looked at each conversation (keyed by providerId).
///
/// The backend deliberately keeps no read receipts (see the messaging
/// package's ADR), so "new messages" is worked out on this device: a
/// conversation is *new* when its last message is later than the moment the
/// thread was last open here. [baseline] is the first time this ran —
/// conversations that already existed then are not suddenly all "new".
class MessageSeen {
  const MessageSeen({required this.baseline, this.seen = const {}});

  final DateTime baseline;
  final Map<String, DateTime> seen;

  bool isNew(String providerId, DateTime lastMessageAt) {
    final since = seen[providerId];
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
      for (final e in (json['seen'] as Map<String, dynamic>).entries) e.key: DateTime.parse(e.value as String),
    },
  );
}

final messageSeenProvider = AsyncNotifierProvider<MessageSeenController, MessageSeen>(MessageSeenController.new);

class MessageSeenController extends AsyncNotifier<MessageSeen> {
  @override
  Future<MessageSeen> build() async {
    final storage = ref.read(secureStorageServiceProvider);
    try {
      final stored = await storage.read(_storageKey);
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

  /// The thread with [providerId] was on screen and showed messages up to [at].
  Future<void> markSeen(String providerId, DateTime at) async {
    final current = await future;
    final previous = current.seen[providerId];
    if (previous != null && !at.isAfter(previous)) return;
    final next = MessageSeen(baseline: current.baseline, seen: {...current.seen, providerId: at.toUtc()});
    state = AsyncData(next);
    await _persist(next);
  }

  Future<void> _persist(MessageSeen value) async {
    try {
      await ref.read(secureStorageServiceProvider).write(_storageKey, jsonEncode(value.toJson()));
    } catch (_) {
      // Best-effort: worst case the count is recomputed from the baseline.
    }
  }
}

/// How many conversations have a message the customer hasn't opened yet. Zero
/// when signed out (no inbox to ask). Re-checks the inbox every couple of
/// minutes while something is watching it (the bottom nav is).
final newMessagesCountProvider = Provider.autoDispose<int>((ref) {
  if (ref.watch(authControllerProvider).value == null) return 0;

  final timer = Timer.periodic(const Duration(minutes: 2), (_) => ref.invalidate(myInboxProvider));
  ref.onDispose(timer.cancel);

  final conversations = ref.watch(myInboxProvider).value;
  final seen = ref.watch(messageSeenProvider).value;
  if (conversations == null || seen == null) return 0;
  return conversations.where((c) => seen.isNew(c.providerId, c.lastMessageAt)).length;
});
