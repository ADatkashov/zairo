import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import 'messaging_exception.dart';
import 'models/chat_message.dart';
import 'models/conversation.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as the other feature APIs.
class MessagingApi {
  final DioClient _dioClient;

  MessagingApi(this._dioClient);

  /// The current customer's own inbox, most recently active first.
  Future<List<Conversation>> myInbox() async {
    final response = await _dioClient.get('/conversations/mine');
    final data = response.data as List<dynamic>;
    return data.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The calling customer's own thread with that one provider, oldest
  /// first — `[]` if they've never messaged this provider (not a 404).
  Future<List<ChatMessage>> threadWithProvider(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/messages');
    final data = response.data as List<dynamic>;
    return data.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Sends as the customer, creating the conversation on first contact.
  Future<ChatMessage> sendToProvider(String providerId, String body) async {
    final response = await _dioClient.post(
      '/providers/$providerId/messages',
      data: {'body': body},
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  /// Sends a message tagged with [bookingId] — the provider is resolved
  /// server-side from the booking, so the caller never needs a providerId
  /// for this one.
  Future<ChatMessage> sendAboutBooking(String bookingId, String body) async {
    try {
      final response = await _dioClient.post(
        '/bookings/$bookingId/messages',
        data: {'body': body},
      );
      return ChatMessage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw const MessagingException(MessagingErrorKey.notYourBooking);
      }
      if (e.response?.statusCode == 404) {
        throw const MessagingException(MessagingErrorKey.bookingNotFound);
      }
      rethrow;
    }
  }
}
