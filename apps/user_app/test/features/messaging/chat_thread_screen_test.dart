import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/messaging/data/messaging_api.dart';
import 'package:zairo/features/messaging/data/models/chat_message.dart';
import 'package:zairo/features/messaging/data/models/conversation.dart';
import 'package:zairo/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:zairo/features/messaging/presentation/screens/chat_thread_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeMessagingApi extends MessagingApi {
  _FakeMessagingApi(this._messages) : super(DioClient(Dio()));

  final List<ChatMessage> _messages;
  String? lastSentBody;

  @override
  Future<List<ChatMessage>> threadWithProvider(String providerId) async =>
      _messages;

  @override
  Future<ChatMessage> sendToProvider(String providerId, String body) async {
    lastSentBody = body;
    final sent = ChatMessage(
      id: 'message-${_messages.length + 1}',
      conversationId: 'conversation-1',
      senderUserId: 'user-1',
      body: body,
      createdAt: DateTime(2026, 1, 4),
    );
    _messages.add(sent);
    return sent;
  }

  @override
  Future<List<Conversation>> myInbox() async => const [];
}

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(
      id: 'user-1',
      email: 'a@example.com',
      displayName: 'A',
      role: 'CUSTOMER',
    );
  }
}

class _LoggedOutAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

void main() {
  testWidgets('a guest is invited to log in: no error, no message box', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingApiProvider.overrideWithValue(_FakeMessagingApi([])),
          authControllerProvider.overrideWith(_LoggedOutAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatThreadScreen(providerId: 'provider-1', providerName: 'Glow Salon'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Log in to message this business'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('shows an empty state with no messages yet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingApiProvider.overrideWithValue(_FakeMessagingApi([])),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatThreadScreen(
            providerId: 'provider-1',
            providerName: 'Glow Salon',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('shows a booking-context chip on a tagged message', (tester) async {
    final messages = [
      ChatMessage(
        id: 'message-1',
        conversationId: 'conversation-1',
        senderUserId: 'provider-user-1',
        body: 'Sure, see you then!',
        createdAt: DateTime(2026, 1, 1),
      ),
      ChatMessage(
        id: 'message-2',
        conversationId: 'conversation-1',
        senderUserId: 'user-1',
        body: 'Can I reschedule my booking?',
        bookingId: 'booking-1',
        createdAt: DateTime(2026, 1, 2),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingApiProvider.overrideWithValue(_FakeMessagingApi(messages)),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatThreadScreen(
            providerId: 'provider-1',
            providerName: 'Glow Salon',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sure, see you then!'), findsOneWidget);
    expect(find.text('Can I reschedule my booking?'), findsOneWidget);
    // Only the second (bookingId-tagged) message carries the chip.
    expect(find.text('About a booking'), findsOneWidget);
  });

  testWidgets('sends a message and clears the compose field', (tester) async {
    final fakeApi = _FakeMessagingApi([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingApiProvider.overrideWithValue(fakeApi),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatThreadScreen(
            providerId: 'provider-1',
            providerName: 'Glow Salon',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Hello there!');
    // The send button is named for screen readers (tooltip), not just an icon.
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastSentBody, 'Hello there!');
    expect(find.text('Hello there!'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Hello there!'), findsNothing);
  });
}
