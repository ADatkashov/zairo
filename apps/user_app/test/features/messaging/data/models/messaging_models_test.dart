import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/messaging/data/models/chat_message.dart';
import 'package:zairo/features/messaging/data/models/conversation.dart';

void main() {
  group('Conversation', () {
    test('parses a full JSON row', () {
      final conversation = Conversation.fromJson({
        'id': 'conversation-1',
        'customerId': 'customer-1',
        'customerDisplayName': 'Amina K.',
        'providerId': 'provider-1',
        'providerName': 'Glow Salon',
        'createdAt': '2026-01-01T10:00:00Z',
        'lastMessageAt': '2026-01-03T09:30:00Z',
      });

      expect(conversation.id, 'conversation-1');
      expect(conversation.customerId, 'customer-1');
      expect(conversation.customerDisplayName, 'Amina K.');
      expect(conversation.providerId, 'provider-1');
      expect(conversation.providerName, 'Glow Salon');
      expect(conversation.createdAt, DateTime.parse('2026-01-01T10:00:00Z'));
      expect(conversation.lastMessageAt, DateTime.parse('2026-01-03T09:30:00Z'));
    });

    test('tolerates a null providerName', () {
      final conversation = Conversation.fromJson({
        'id': 'conversation-1',
        'customerId': 'customer-1',
        'customerDisplayName': null,
        'providerId': 'provider-1',
        'providerName': null,
        'createdAt': '2026-01-01T10:00:00Z',
        'lastMessageAt': '2026-01-01T10:00:00Z',
      });

      expect(conversation.providerName, isNull);
      expect(conversation.customerDisplayName, isNull);
    });
  });

  group('ChatMessage', () {
    test('parses a plain message with no booking context', () {
      final message = ChatMessage.fromJson({
        'id': 'message-1',
        'conversationId': 'conversation-1',
        'senderUserId': 'user-1',
        'body': 'Hi, are you open on Sunday?',
        'bookingId': null,
        'createdAt': '2026-01-01T10:00:00Z',
      });

      expect(message.id, 'message-1');
      expect(message.conversationId, 'conversation-1');
      expect(message.senderUserId, 'user-1');
      expect(message.body, 'Hi, are you open on Sunday?');
      expect(message.bookingId, isNull);
      expect(message.createdAt, DateTime.parse('2026-01-01T10:00:00Z'));
    });

    test('parses a message tagged with a bookingId', () {
      final message = ChatMessage.fromJson({
        'id': 'message-2',
        'conversationId': 'conversation-1',
        'senderUserId': 'user-1',
        'body': 'Can I reschedule my booking?',
        'bookingId': 'booking-1',
        'createdAt': '2026-01-02T11:00:00Z',
      });

      expect(message.bookingId, 'booking-1');
    });
  });
}
