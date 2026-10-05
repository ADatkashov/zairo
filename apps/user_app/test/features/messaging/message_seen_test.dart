import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/messaging/data/messaging_api.dart';
import 'package:zairo/features/messaging/data/models/conversation.dart';
import 'package:zairo/features/messaging/presentation/providers/message_seen_provider.dart';
import 'package:zairo/features/messaging/presentation/providers/messaging_providers.dart';

class _MemoryStorage extends SecureStorageService {
  _MemoryStorage() : super(const FlutterSecureStorage());

  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakeMessagingApi extends MessagingApi {
  _FakeMessagingApi(this.conversations) : super(DioClient(Dio()));

  final List<Conversation> conversations;

  @override
  Future<List<Conversation>> myInbox() async => conversations;
}

class _LoggedIn extends AuthController {
  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'u1', email: 'a@example.com', displayName: 'A', role: 'CUSTOMER');
}

class _LoggedOut extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

Conversation _conversation(String providerId, DateTime lastMessageAt) => Conversation(
  id: 'c-$providerId',
  customerId: 'u1',
  providerId: providerId,
  createdAt: DateTime(2020),
  lastMessageAt: lastMessageAt,
);

void main() {
  group('MessageSeen.isNew', () {
    final baseline = DateTime.utc(2026, 1, 10);

    test('a conversation older than the first run is not new', () {
      final seen = MessageSeen(baseline: baseline);
      expect(seen.isNew('p1', DateTime.utc(2026, 1, 9)), isFalse);
      expect(seen.isNew('p1', DateTime.utc(2026, 1, 11)), isTrue);
    });

    test('opening a thread clears it until a later message arrives', () {
      final seen = MessageSeen(baseline: baseline, seen: {'p1': DateTime.utc(2026, 1, 12)});
      expect(seen.isNew('p1', DateTime.utc(2026, 1, 12)), isFalse);
      expect(seen.isNew('p1', DateTime.utc(2026, 1, 13)), isTrue);
      expect(seen.isNew('p2', DateTime.utc(2026, 1, 12)), isTrue, reason: 'other threads are unaffected');
    });

    test('survives a round trip through storage', () {
      final seen = MessageSeen(baseline: baseline, seen: {'p1': DateTime.utc(2026, 1, 12)});
      final again = MessageSeen.fromJson(seen.toJson());
      expect(again.baseline, baseline);
      expect(again.seen['p1'], DateTime.utc(2026, 1, 12));
    });
  });

  group('newMessagesCountProvider', () {
    ProviderContainer containerFor(List<Conversation> conversations, {bool loggedIn = true}) {
      final container = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_MemoryStorage()),
          messagingApiProvider.overrideWithValue(_FakeMessagingApi(conversations)),
          authControllerProvider.overrideWith(loggedIn ? _LoggedIn.new : _LoggedOut.new),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> settle(ProviderContainer container) async {
      container.listen(newMessagesCountProvider, (_, _) {});
      await container.read(authControllerProvider.future);
      await container.read(myInboxProvider.future);
      await container.read(messageSeenProvider.future);
    }

    test('counts conversations with a message newer than the last time they were opened', () async {
      final later = DateTime.now().add(const Duration(hours: 1));
      final container = containerFor([_conversation('p1', later), _conversation('p2', later)]);
      await settle(container);
      expect(container.read(newMessagesCountProvider), 2);

      await container.read(messageSeenProvider.notifier).markSeen('p1', later);
      expect(container.read(newMessagesCountProvider), 1);
    });

    test('is zero when signed out', () async {
      final container = containerFor([_conversation('p1', DateTime.now().add(const Duration(hours: 1)))], loggedIn: false);
      container.listen(newMessagesCountProvider, (_, _) {});
      await container.read(authControllerProvider.future);
      expect(container.read(newMessagesCountProvider), 0);
    });
  });
}
