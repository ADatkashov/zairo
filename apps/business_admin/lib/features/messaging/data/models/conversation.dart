/// Mirrors backend's MessagingDtos.ConversationResponse
/// (backend/messaging/.../MessagingDtos.java) — one 1:1 customer↔business
/// thread. [customerDisplayName]/[providerName] are resolved server-side
/// (there's no client-usable "get user by id" — see this module's
/// package-info.java), and `null` only when the backend genuinely has no
/// name to give, never a placeholder this side invents.
library;

class Conversation {
  final String id;
  final String customerId;
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
