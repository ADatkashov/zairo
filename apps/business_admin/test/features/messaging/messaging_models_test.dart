import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/messaging/data/models/chat_message.dart';
import 'package:business_admin/features/messaging/data/models/conversation.dart';

void main() {
  group('Conversation', () {
    test('fromJson parses every field', () {
      final conversation = Conversation.fromJson({
        'id': 'conv-1',
        'customerId': 'cust-1',
        'customerDisplayName': 'Aigerim Bekova',
        'providerId': 'provider-1',
        'providerName': 'Aigerim Beauty Salon',
        'createdAt': '2026-08-01T10:00:00Z',
        'lastMessageAt': '2026-08-02T12:30:00Z',
      });

      expect(conversation.id, 'conv-1');
      expect(conversation.customerId, 'cust-1');
      expect(conversation.customerDisplayName, 'Aigerim Bekova');
      expect(conversation.providerId, 'provider-1');
      expect(conversation.providerName, 'Aigerim Beauty Salon');
      expect(conversation.createdAt, DateTime.parse('2026-08-01T10:00:00Z'));
      expect(
        conversation.lastMessageAt,
        DateTime.parse('2026-08-02T12:30:00Z'),
      );
    });

    test('fromJson tolerates a null customerDisplayName -- there is no client-usable name lookup', () {
      final conversation = Conversation.fromJson({
        'id': 'conv-1',
        'customerId': 'cust-1',
        'customerDisplayName': null,
        'providerId': 'provider-1',
        'providerName': null,
        'createdAt': '2026-08-01T10:00:00Z',
        'lastMessageAt': '2026-08-01T10:00:00Z',
      });

      expect(conversation.customerDisplayName, isNull);
      expect(conversation.providerName, isNull);
    });
  });

  group('ChatMessage', () {
    test('fromJson parses a plain message with no booking context', () {
      final message = ChatMessage.fromJson({
        'id': 'msg-1',
        'conversationId': 'conv-1',
        'senderUserId': 'cust-1',
        'body': 'Hi, is this Saturday slot still open?',
        'bookingId': null,
        'createdAt': '2026-08-01T10:00:00Z',
      });

      expect(message.id, 'msg-1');
      expect(message.conversationId, 'conv-1');
      expect(message.senderUserId, 'cust-1');
      expect(message.body, 'Hi, is this Saturday slot still open?');
      expect(message.bookingId, isNull);
      expect(message.createdAt, DateTime.parse('2026-08-01T10:00:00Z'));
    });

    test('fromJson parses a message tagged with a bookingId', () {
      final message = ChatMessage.fromJson({
        'id': 'msg-2',
        'conversationId': 'conv-1',
        'senderUserId': 'cust-1',
        'body': "Can I move today's appointment?",
        'bookingId': 'booking-1',
        'createdAt': '2026-08-01T11:00:00Z',
      });

      expect(message.bookingId, 'booking-1');
    });
  });
}
