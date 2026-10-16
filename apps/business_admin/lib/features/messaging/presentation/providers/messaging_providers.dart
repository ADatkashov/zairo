import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/messaging_api.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/conversation.dart';

final messagingApiProvider = Provider<MessagingApi>((ref) {
  return MessagingApi(ref.watch(dioClientProvider));
});

/// One provider's inbox -- [BusinessInboxScreen] resolves which providerId
/// to use exactly like [CampaignCenterScreen] does, then keys this by it.
final providerInboxProvider = FutureProvider.autoDispose
    .family<List<Conversation>, String>((ref, providerId) {
      return ref.watch(messagingApiProvider).inboxForProvider(providerId);
    });

/// One conversation's full thread, keyed by conversationId.
final conversationThreadProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, conversationId) {
      return ref
          .watch(messagingApiProvider)
          .threadForConversation(conversationId);
    });
