import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/messaging/data/api/messaging_api.dart';
import 'package:business_admin/features/messaging/data/models/chat_message.dart';
import 'package:business_admin/features/messaging/data/models/conversation.dart';
import 'package:business_admin/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:business_admin/features/messaging/presentation/screens/business_inbox_screen.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _LoggedInOwnerController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'owner-1', email: 'owner@example.com', displayName: 'Jamie Owner', role: 'PROVIDER_OWNER');
  }
}

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi(this._providers) : super(DioClient(Dio()));

  final List<AdminProvider> _providers;

  @override
  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async => _providers;
}

class _FakeMessagingApi extends MessagingApi {
  _FakeMessagingApi() : super(DioClient(Dio()));

  List<Conversation> conversations = const [];
  Object? listError;

  @override
  Future<List<Conversation>> inboxForProvider(String providerId) async {
    if (listError != null) throw listError!;
    return conversations;
  }

  @override
  Future<List<ChatMessage>> threadForConversation(String conversationId) async => const [];
}

final _provider = const AdminProvider(id: 'provider-1', ownerUserId: 'owner-1', name: 'Glow Salon', vertical: 'beauty', status: 'ACTIVE');

Conversation _conversation(String id, {String? customerDisplayName = 'Aigerim Bekova'}) => Conversation(
      id: id,
      customerId: 'cust-$id',
      customerDisplayName: customerDisplayName,
      providerId: 'provider-1',
      providerName: 'Glow Salon',
      createdAt: DateTime(2026, 9, 10, 9, 0),
      lastMessageAt: DateTime(2026, 9, 13, 14, 30),
    );

Widget _wrap({required _FakeMessagingApi api, List<AdminProvider>? providers}) => ProviderScope(
      overrides: [
        salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi(providers ?? [_provider])),
        messagingApiProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(_LoggedInOwnerController.new),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BusinessInboxScreen(ownerUserId: 'owner-1'),
      ),
    );

void main() {
  testWidgets('shows the empty state when the owner has no businesses yet', (tester) async {
    final api = _FakeMessagingApi();

    await tester.pumpWidget(_wrap(api: api, providers: const []));
    await tester.pumpAndSettle();

    expect(find.text('Create a business first to see its conversations.'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when the inbox fails to load', (tester) async {
    final api = _FakeMessagingApi()..listError = Exception('network down');

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't load conversations"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows the empty state when the business has no conversations yet', (tester) async {
    final api = _FakeMessagingApi()..conversations = const [];

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(find.text('No conversations yet.'), findsOneWidget);
  });

  testWidgets('lists conversations with a customer-name fallback for a null display name', (tester) async {
    final api = _FakeMessagingApi()
      ..conversations = [
        _conversation('conv-1'),
        _conversation('conv-2', customerDisplayName: null),
      ];

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Aigerim Bekova'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
  });

  testWidgets('tapping a conversation pushes the thread screen with its display name as the title', (tester) async {
    final api = _FakeMessagingApi()..conversations = [_conversation('conv-1')];

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aigerim Bekova'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Aigerim Bekova'), findsOneWidget);
  });
}
