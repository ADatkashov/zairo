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
import 'package:business_admin/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:business_admin/features/messaging/presentation/screens/business_chat_thread_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _FakeMessagingApi extends MessagingApi {
  _FakeMessagingApi() : super(DioClient(Dio()));

  List<ChatMessage> messages = const [];
  String? lastReplyBody;
  Object? replyError;

  @override
  Future<List<ChatMessage>> threadForConversation(String conversationId) async => messages;

  @override
  Future<ChatMessage> reply(String conversationId, String body) async {
    if (replyError != null) throw replyError!;
    lastReplyBody = body;
    final sent = ChatMessage(
      id: 'sent-${messages.length}',
      conversationId: conversationId,
      senderUserId: 'owner-1',
      body: body,
      createdAt: DateTime(2026, 9, 13, 15, 0),
    );
    messages = [...messages, sent];
    return sent;
  }
}

class _LoggedInOwnerController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'owner-1', email: 'owner@example.com', displayName: 'Jamie Owner', role: 'PROVIDER_OWNER');
  }
}

Widget _wrap({required _FakeMessagingApi api}) => ProviderScope(
      overrides: [
        messagingApiProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(_LoggedInOwnerController.new),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BusinessChatThreadScreen(conversationId: 'conv-1', customerDisplayName: 'Aigerim Bekova'),
      ),
    );

void main() {
  testWidgets('shows the empty state before the first message', (tester) async {
    final api = _FakeMessagingApi();

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(find.text('No messages yet. Say hello!'), findsOneWidget);
  });

  testWidgets('renders each message body and a booking chip only on tagged messages', (tester) async {
    final api = _FakeMessagingApi()
      ..messages = [
        ChatMessage(
          id: 'm1',
          conversationId: 'conv-1',
          senderUserId: 'cust-1',
          body: 'Is Saturday still open?',
          createdAt: DateTime(2026, 9, 13, 9, 0),
        ),
        ChatMessage(
          id: 'm2',
          conversationId: 'conv-1',
          senderUserId: 'owner-1',
          body: 'Yes, 3pm works!',
          bookingId: 'booking-1',
          createdAt: DateTime(2026, 9, 13, 9, 5),
        ),
      ];

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Is Saturday still open?'), findsOneWidget);
    expect(find.text('Yes, 3pm works!'), findsOneWidget);
    expect(find.text('About a booking'), findsOneWidget);
  });

  testWidgets('sending a message clears the compose field and shows the new message', (tester) async {
    final api = _FakeMessagingApi();

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'On my way!');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(api.lastReplyBody, 'On my way!');
    expect(find.text('On my way!'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'On my way!'), findsNothing);
  });

  testWidgets('a send failure shows a snackbar and keeps the draft', (tester) async {
    final api = _FakeMessagingApi()..replyError = Exception('offline');

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't send message"), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });
}
