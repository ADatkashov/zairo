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
import 'package:zairo/features/messaging/presentation/screens/conversations_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeMessagingApi extends MessagingApi {
  _FakeMessagingApi(this._conversations) : super(DioClient(Dio()));

  final List<Conversation> _conversations;

  @override
  Future<List<Conversation>> myInbox() async => _conversations;

  @override
  Future<List<ChatMessage>> threadWithProvider(String providerId) async =>
      const [];
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
  testWidgets('shows a login gate when logged out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingApiProvider.overrideWithValue(_FakeMessagingApi(const [])),
          authControllerProvider.overrideWith(_LoggedOutAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ConversationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in to see your messages'), findsOneWidget);
  });

  testWidgets('shows an empty state with no conversations', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingApiProvider.overrideWithValue(_FakeMessagingApi(const [])),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ConversationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('lists conversations and opens the thread on tap', (tester) async {
    final conversation = Conversation(
      id: 'conversation-1',
      customerId: 'user-1',
      providerId: 'provider-1',
      providerName: 'Glow Salon',
      createdAt: DateTime(2026, 1, 1),
      lastMessageAt: DateTime(2026, 1, 3, 9, 30),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingApiProvider.overrideWithValue(
            _FakeMessagingApi([conversation]),
          ),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ConversationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glow Salon'), findsOneWidget);

    await tester.tap(find.text('Glow Salon'));
    await tester.pumpAndSettle();

    // ChatThreadScreen pushed with the tapped conversation's provider name
    // as its AppBar title, and its own empty state since threadWithProvider
    // returns nothing for this fake.
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('falls back to a generic name when providerName is null', (
    tester,
  ) async {
    final conversation = Conversation(
      id: 'conversation-1',
      customerId: 'user-1',
      providerId: 'provider-1',
      createdAt: DateTime(2026, 1, 1),
      lastMessageAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingApiProvider.overrideWithValue(
            _FakeMessagingApi([conversation]),
          ),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ConversationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Business'), findsOneWidget);
  });
}
