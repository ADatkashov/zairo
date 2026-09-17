import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/messaging_api.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/conversation.dart';

final messagingApiProvider = Provider<MessagingApi>((ref) {
  return MessagingApi(ref.watch(dioClientProvider));
});

final myInboxProvider = FutureProvider.autoDispose<List<Conversation>>((ref) {
  return ref.watch(messagingApiProvider).myInbox();
});

/// Keyed by providerId, not conversationId — the customer app never has a
/// client-side conversationId to key off of before a thread's first
/// message is sent, and every customer-facing messaging endpoint is
/// rooted at providerId anyway (see ChatThreadScreen's doc comment).
final threadWithProviderProvider =
    FutureProvider.autoDispose.family<List<ChatMessage>, String>((ref, providerId) {
  return ref.watch(messagingApiProvider).threadWithProvider(providerId);
});
