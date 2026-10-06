import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/billing/data/billing_api.dart';
import 'package:business_admin/features/billing/data/models/subscription.dart';
import 'package:business_admin/features/billing/presentation/providers/billing_providers.dart';
import 'package:business_admin/features/messaging/data/api/messaging_api.dart';
import 'package:business_admin/features/messaging/data/models/conversation.dart';
import 'package:business_admin/features/messaging/presentation/providers/message_seen_provider.dart';
import 'package:business_admin/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import '../../app/admin_test_harness.dart';

class _MemoryStorage extends SecureStorageService {
  _MemoryStorage() : super(const FlutterSecureStorage());

  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi() : super(DioClient(Dio()));

  @override
  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async => const [
    AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE'),
  ];
}

class _FakeMessagingApi extends MessagingApi {
  _FakeMessagingApi(this.conversations) : super(DioClient(Dio()));

  final List<Conversation> conversations;

  @override
  Future<List<Conversation>> inboxForProvider(String providerId) async => conversations;
}

class _FakeBillingApi extends BillingApi {
  _FakeBillingApi() : super(DioClient(Dio()));

  @override
  Future<Subscription> getMine() async => Subscription(
    id: 'sub-1',
    ownerUserId: 'owner-1',
    plan: 'PRO',
    status: 'ACTIVE',
    limits: const PlanLimits(
      maxProviders: 5,
      maxStaffPerProvider: 20,
      maxBookingsPerMonth: 2147483647,
      recurringScheduleAllowed: true,
    ),
    currentPeriodStart: DateTime(2026, 1, 1),
    currentPeriodEnd: DateTime(2026, 2, 1),
    cancelAtPeriodEnd: false,
  );
}

class _Owner extends AuthController {
  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'owner-1', email: 'o@example.com', displayName: 'Jamie Owner', role: 'PROVIDER_OWNER');
}

Conversation _conversation(String id, DateTime lastMessageAt) => Conversation(
  id: id,
  customerId: 'c-$id',
  providerId: 'p1',
  createdAt: DateTime(2020),
  lastMessageAt: lastMessageAt,
);

List<Override> _overrides(List<Conversation> conversations) => [
  secureStorageServiceProvider.overrideWithValue(_MemoryStorage()),
  salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi()),
  messagingApiProvider.overrideWithValue(_FakeMessagingApi(conversations)),
  billingApiProvider.overrideWithValue(_FakeBillingApi()),
  authControllerProvider.overrideWith(_Owner.new),
];

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('MessageSeen: a conversation is new until its thread has been opened past its last message', () {
    final baseline = DateTime.utc(2026, 1, 10);
    final seen = MessageSeen(baseline: baseline, seen: {'c1': DateTime.utc(2026, 1, 12)});

    expect(seen.isNew('c0', DateTime.utc(2026, 1, 9)), isFalse, reason: 'older than the first run');
    expect(seen.isNew('c2', DateTime.utc(2026, 1, 11)), isTrue);
    expect(seen.isNew('c1', DateTime.utc(2026, 1, 12)), isFalse);
    expect(seen.isNew('c1', DateTime.utc(2026, 1, 13)), isTrue);
  });

  testWidgets('the Messages tab counts conversations with something new', (tester) async {
    _phone(tester);
    final later = DateTime.now().add(const Duration(hours: 1));

    await pumpAdminApp(
      tester,
      overrides: _overrides([_conversation('a', later), _conversation('b', later), _conversation('old', DateTime(2020))]),
    );

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('no badge when nothing is new', (tester) async {
    _phone(tester);

    await pumpAdminApp(tester, overrides: _overrides([_conversation('old', DateTime(2020))]));

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsNothing);
  });
}
