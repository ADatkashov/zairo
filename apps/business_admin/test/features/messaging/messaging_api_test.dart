import 'package:business_admin/features/messaging/data/api/messaging_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

void main() {
  late FakeHttp http;
  late MessagingApi api;

  setUp(() {
    http = FakeHttp();
    api = MessagingApi(http.client());
  });

  test(
    'inboxForProvider parses conversations, with and without display names',
    () async {
      http.reply('GET', '/providers/p1/conversations', [
        {
          'id': 'cv1',
          'customerId': 'u1',
          'customerDisplayName': 'Aigerim',
          'providerId': 'p1',
          'providerName': 'Glow Salon',
          'createdAt': '2026-10-01T10:00:00Z',
          'lastMessageAt': '2026-10-12T10:00:00Z',
        },
        {
          'id': 'cv2',
          'customerId': 'u2',
          'providerId': 'p1',
          'createdAt': '2026-10-02T10:00:00Z',
          'lastMessageAt': '2026-10-11T10:00:00Z',
        },
      ]);

      final inbox = await api.inboxForProvider('p1');

      expect(inbox.map((c) => c.customerDisplayName), ['Aigerim', null]);
      expect(inbox.map((c) => c.providerName), ['Glow Salon', null]);
      expect(inbox.first.lastMessageAt, DateTime.utc(2026, 10, 12, 10));
      expect(inbox.first.createdAt, DateTime.utc(2026, 10, 1, 10));
      expect([inbox.first.customerId, inbox.first.providerId], ['u1', 'p1']);
    },
  );

  test(
    'threadForConversation parses messages, including one linked to a booking',
    () async {
      http.reply('GET', '/conversations/cv1/messages', [
        {
          'id': 'm1',
          'conversationId': 'cv1',
          'senderUserId': 'u1',
          'body': 'Hello',
          'createdAt': '2026-10-12T10:00:00Z',
        },
        {
          'id': 'm2',
          'conversationId': 'cv1',
          'senderUserId': 'o1',
          'body': 'Hi!',
          'bookingId': 'b1',
          'createdAt': '2026-10-12T10:01:00Z',
        },
      ]);

      final thread = await api.threadForConversation('cv1');

      expect(thread.map((m) => m.body), ['Hello', 'Hi!']);
      expect(thread.map((m) => m.bookingId), [null, 'b1']);
      expect(thread.map((m) => m.senderUserId), ['u1', 'o1']);
      expect(thread.first.createdAt, DateTime.utc(2026, 10, 12, 10));
    },
  );

  test('reply posts the text and returns the stored message', () async {
    http.reply('POST', '/conversations/cv1/messages', {
      'id': 'm3',
      'conversationId': 'cv1',
      'senderUserId': 'o1',
      'body': 'See you at 10',
      'createdAt': '2026-10-12T11:00:00Z',
    });

    final message = await api.reply('cv1', 'See you at 10');

    expect(http.bodyOf('POST', '/conversations/cv1/messages'), {
      'body': 'See you at 10',
    });
    expect(
      [message.id, message.body, message.conversationId],
      ['m3', 'See you at 10', 'cv1'],
    );
  });
}
