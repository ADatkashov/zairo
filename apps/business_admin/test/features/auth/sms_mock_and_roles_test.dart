import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/auth_api.dart';
import 'package:business_admin/features/auth/data/models/sms_mode.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/auth/presentation/screens/phone_otp_password_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

/// Records every request and answers with a canned token response.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  static final _tokens = jsonEncode({
    'accessToken': 'a',
    'refreshToken': 'r',
    'user': {'id': 'u1', 'email': null, 'displayName': 'Owner', 'role': 'PROVIDER_OWNER', 'avatarUrl': null},
  });

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(_tokens, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Widget _wrap(Widget home, {SmsMode? mode}) => ProviderScope(
      overrides: [
        smsModeProvider.overrideWith((ref) async => mode ?? SmsMode.real),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  group('the business app creates PROVIDER_OWNER accounts', () {
    late _RecordingAdapter adapter;
    late AuthApi api;

    setUp(() {
      adapter = _RecordingAdapter();
      api = AuthApi(DioClient(Dio()..httpClientAdapter = adapter));
    });

    test('phone registration sends role PROVIDER_OWNER', () async {
      await api.registerWithPhone(phone: '+77001234567', code: '123456', displayName: 'Owner', password: 'password123');

      expect(adapter.requests.single.path, endsWith('/auth/phone/register'));
      expect((adapter.requests.single.data as Map)['role'], 'PROVIDER_OWNER');
    });

    test('Google sign-in sends role PROVIDER_OWNER', () async {
      await api.loginWithGoogle('id-token');

      expect(adapter.requests.single.path, endsWith('/auth/google'));
      expect((adapter.requests.single.data as Map)['role'], 'PROVIDER_OWNER');
    });

    test('Apple sign-in sends role PROVIDER_OWNER and the name', () async {
      await api.loginWithApple('identity-token', displayName: 'Dana');

      expect(adapter.requests.single.path, endsWith('/auth/apple'));
      expect((adapter.requests.single.data as Map)['role'], 'PROVIDER_OWNER');
      expect((adapter.requests.single.data as Map)['displayName'], 'Dana');
    });
  });

  group('SMS mock hint', () {
    testWidgets('shows the fixed code while the server mocks SMS', (tester) async {
      await tester.pumpWidget(_wrap(
        const PhoneOtpPasswordScreen(phone: '+77001234567', isNewAccount: true),
        mode: const SmsMode(mock: true, mockCode: '123456'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Test mode: no real SMS is sent. Enter the code 123456.'), findsOneWidget);
    });

    testWidgets('shows nothing when SMS is real', (tester) async {
      await tester.pumpWidget(_wrap(const PhoneOtpPasswordScreen(phone: '+77001234567', isNewAccount: true)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Test mode'), findsNothing);
    });
  });
}
