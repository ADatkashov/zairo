import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  Future<List<ChatMessage>> threadForConversation(
    String conversationId,
  ) async => messages;

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

class _InMemoryStorage extends SecureStorageService {
  _InMemoryStorage([Map<String, String>? initial])
    : super(const FlutterSecureStorage()) {
    if (initial != null) store.addAll(initial);
  }

  final Map<String, String> store = {};

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> delete(String key) async => store.remove(key);

  @override
  Future<void> deleteAll() async => store.clear();
}

class _LoggedInOwnerController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(
      id: 'owner-1',
      email: 'owner@example.com',
      displayName: 'Jamie Owner',
      role: 'PROVIDER_OWNER',
    );
  }
}

Widget _wrap({required _FakeMessagingApi api, _InMemoryStorage? storage}) =>
    ProviderScope(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(
          storage ?? _InMemoryStorage(),
        ),
        messagingApiProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(_LoggedInOwnerController.new),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BusinessChatThreadScreen(
          conversationId: 'conv-1',
          customerDisplayName: 'Aigerim Bekova',
        ),
      ),
    );

void main() {
  testWidgets('shows the empty state before the first message', (tester) async {
    final api = _FakeMessagingApi();

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    expect(find.text('No messages yet. Say hello!'), findsOneWidget);
  });

  testWidgets(
    'renders each message body and a booking chip only on tagged messages',
    (tester) async {
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
    },
  );

  testWidgets(
    'sending a message clears the compose field and shows the new message',
    (tester) async {
      final api = _FakeMessagingApi();

      await tester.pumpWidget(_wrap(api: api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'On my way!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(api.lastReplyBody, 'On my way!');
      expect(find.text('On my way!'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'On my way!'), findsNothing);
    },
  );

  testWidgets('a send failure shows a snackbar and keeps the draft', (
    tester,
  ) async {
    final api = _FakeMessagingApi()..replyError = Exception('offline');

    await tester.pumpWidget(_wrap(api: api));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't send message"), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets(
    'a ready sentence fills the field, can be edited, and is sent as typed',
    (tester) async {
      final api = _FakeMessagingApi();
      await tester.pumpWidget(_wrap(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes, that time works. See you then!'));
      await tester.pump();
      expect(
        find.widgetWithText(TextField, 'Yes, that time works. See you then!'),
        findsOneWidget,
      );

      // Choosing another sentence replaces the first rather than stacking them.
      await tester.tap(find.text("Thank you! We'll be in touch shortly."));
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(api.lastReplyBody, "Thank you! We'll be in touch shortly.");
    },
  );

  testWidgets(
    'the ready sentences and the field fit a 320 px phone with a large font in the dark theme',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageServiceProvider.overrideWithValue(_InMemoryStorage()),
            messagingApiProvider.overrideWithValue(_FakeMessagingApi()),
            authControllerProvider.overrideWith(_LoggedInOwnerController.new),
          ],
          child: MaterialApp(
            theme: factoryDarkTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const BusinessChatThreadScreen(
              conversationId: 'conv-1',
              customerDisplayName: 'Aigerim Bekova',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the owner can write their own ready sentences; they replace the built-in ones and are remembered',
    (tester) async {
      final storage = _InMemoryStorage();
      await tester.pumpWidget(
        _wrap(api: _FakeMessagingApi(), storage: storage),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit ready sentences'));
      await tester.pumpAndSettle();
      expect(find.text('Your ready sentences'), findsOneWidget);
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'We are open until 9 pm.');
      await tester.enterText(fields.at(1), '');
      await tester.enterText(fields.at(2), '  Parking is free.  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Two sentences remain (the empty field was dropped), trimmed, and the built-in ones are gone.
      expect(find.text('We are open until 9 pm.'), findsOneWidget);
      expect(find.text('Parking is free.'), findsOneWidget);
      expect(find.text('Yes, that time works. See you then!'), findsNothing);
      expect(
        storage.store['chat_quick_replies'],
        '["We are open until 9 pm.","Parking is free."]',
      );

      // A fresh start on the same device reads them back.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _wrap(api: _FakeMessagingApi(), storage: storage),
      );
      await tester.pumpAndSettle();
      expect(find.text('We are open until 9 pm.'), findsOneWidget);
    },
  );

  testWidgets(
    'emptying every field, or choosing the built-in ones, brings the built-in sentences back',
    (tester) async {
      final storage = _InMemoryStorage({'chat_quick_replies': '["Only mine"]'});
      await tester.pumpWidget(
        _wrap(api: _FakeMessagingApi(), storage: storage),
      );
      await tester.pumpAndSettle();
      expect(find.text('Only mine'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit ready sentences'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Yes, that time works. See you then!'), findsOneWidget);
      expect(storage.store.containsKey('chat_quick_replies'), isFalse);

      storage.store['chat_quick_replies'] = '["Again mine"]';
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _wrap(api: _FakeMessagingApi(), storage: storage),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit ready sentences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to the built-in ones'));
      await tester.pumpAndSettle();
      expect(find.text('Yes, that time works. See you then!'), findsOneWidget);
      expect(storage.store.containsKey('chat_quick_replies'), isFalse);
    },
  );

  testWidgets('a damaged stored value falls back to the built-in sentences', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        api: _FakeMessagingApi(),
        storage: _InMemoryStorage({'chat_quick_replies': 'not json'}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yes, that time works. See you then!'), findsOneWidget);
  });

  testWidgets(
    'the edit dialog fits a 320 px phone with a large font in the dark theme',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageServiceProvider.overrideWithValue(_InMemoryStorage()),
            messagingApiProvider.overrideWithValue(_FakeMessagingApi()),
            authControllerProvider.overrideWith(_LoggedInOwnerController.new),
          ],
          child: MaterialApp(
            theme: factoryDarkTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const BusinessChatThreadScreen(
              conversationId: 'conv-1',
              customerDisplayName: 'Aigerim Bekova',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit ready sentences'));
      await tester.pumpAndSettle();
      expect(find.text('Your ready sentences'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
