/// Mirrors backend's MessagingDtos.ConversationResponse
/// (backend/messaging/.../MessagingDtos.java).
class Conversation {
  final String id;
  final String customerId;

  /// Always this same customer's own name on `/conversations/mine` — not
  /// useful for display there (see [providerName] for what the customer
  /// app actually shows in a conversation row).
  final String? customerDisplayName;
  final String providerId;
  final String? providerName;
  final DateTime createdAt;
  final DateTime lastMessageAt;

  const Conversation({
    required this.id,
    required this.customerId,
    this.customerDisplayName,
    required this.providerId,
    this.providerName,
    required this.createdAt,
    required this.lastMessageAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      customerDisplayName: json['customerDisplayName'] as String?,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
    );
  }
}
