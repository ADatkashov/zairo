import 'package:core_network/core_network.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Wraps backend/messaging's REST surface (backend/messaging/.../
/// MessagingController.java) from the business owner's point of view --
/// deliberately poll-based, no WebSocket/read-receipts (see that module's
/// package-info.java). Not final: tests substitute a subclass, same
/// pattern as [CampaignCenterApi].
class MessagingApi {
  final DioClient _dioClient;

  MessagingApi(this._dioClient);

  /// That provider's own inbox -- owner-only, most recently active first.
  Future<List<Conversation>> inboxForProvider(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/conversations');
    return (response.data as List<dynamic>)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The full thread for one conversation, oldest first.
  Future<List<ChatMessage>> threadForConversation(String conversationId) async {
    final response = await _dioClient.get('/conversations/$conversationId/messages');
    return (response.data as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Replies as the business owner. The backend validates non-blank/≤2000
  /// chars server-side (400 otherwise) -- callers still trim/guard client
  /// side for a snappier disabled-send-button experience.
  Future<ChatMessage> reply(String conversationId, String body) async {
    final response = await _dioClient.post(
      '/conversations/$conversationId/messages',
      data: {'body': body},
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }
}
