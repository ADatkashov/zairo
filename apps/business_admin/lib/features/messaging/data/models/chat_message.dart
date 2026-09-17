/// Mirrors backend's MessagingDtos.MessageResponse
/// (backend/messaging/.../MessagingDtos.java) — one message in a
/// conversation, from either side. [bookingId] is set only when the
/// customer sent this particular message from a booking's detail screen
/// (see MessagingController#sendAboutBooking); there is no cross-app
/// booking lookup available here, so it only ever backs a non-interactive
/// "about a booking" chip, never a navigation target.
library;

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderUserId;
  final String body;
  final String? bookingId;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.body,
    this.bookingId,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderUserId: json['senderUserId'] as String,
      body: json['body'] as String,
      bookingId: json['bookingId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
