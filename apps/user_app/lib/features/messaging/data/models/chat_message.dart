/// Mirrors backend's MessagingDtos.MessageResponse
/// (backend/messaging/.../MessagingDtos.java).
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderUserId;
  final String body;

  /// Set when this message was sent through the "message about this
  /// booking" flow (`POST /bookings/{bookingId}/messages`) — null for a
  /// plain conversation message.
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
