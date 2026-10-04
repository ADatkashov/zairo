import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/auth_api.dart';
import 'package:zairo/features/auth/data/models/sms_mode.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/auth/presentation/screens/phone_otp_password_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi(this.mode) : super(DioClient(Dio()));

  final SmsMode? mode; // null = the request fails

  @override
  Future<SmsMode> smsMode() async {
    if (mode == null) throw Exception('network down');
    return mode!;
  }
}

class _InMemorySecureStorageService extends SecureStorageService {
  _InMemorySecureStorageService() : super(const FlutterSecureStorage());

  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();
}

Widget _wrap(AuthApi api) {
  return ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(api),
      secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PhoneOtpPasswordScreen(phone: '+77001234567', isNewAccount: true),
    ),
  );
}

void main() {
  testWidgets('shows the fixed code while the server mocks SMS', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthApi(const SmsMode(mock: true, mockCode: '123456'))));
    await tester.pumpAndSettle();

    expect(find.text('Test mode: no real SMS is sent. Enter the code 123456.'), findsOneWidget);
  });

  testWidgets('shows nothing when SMS is real', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthApi(SmsMode.real)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Test mode'), findsNothing);
  });

  testWidgets('a failed sms-mode request just hides the hint', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthApi(null)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Test mode'), findsNothing);
    expect(find.text('Create account'), findsOneWidget); // the screen itself is unaffected
  });
}
