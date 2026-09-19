import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/auth_api.dart';
import 'package:zairo/features/auth/data/auth_exception.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(DioClient(Dio()));

  String? lastRequestedPhone;
  Object? errorOnRequest;

  @override
  Future<void> requestPhoneOtp(String phone) async {
    if (errorOnRequest != null) throw errorOnRequest!;
    lastRequestedPhone = phone;
  }
}

/// PhoneLoginScreen reaches through authControllerProvider.notifier, which
/// lazily runs AuthController.build() — that touches secure storage (see
/// auth_controller_test.dart), so it needs a fake here too, not just
/// authApiProvider, even though this screen never displays a restored
/// session itself.
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

Widget _wrap(AuthApi fakeApi) {
  return ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(fakeApi),
      secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PhoneLoginScreen())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('rejects a too-short phone number without calling the API', (tester) async {
    final fakeApi = _FakeAuthApi();
    await tester.pumpWidget(_wrap(fakeApi));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '+7');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your phone'), findsOneWidget);
    expect(fakeApi.lastRequestedPhone, isNull);
  });

  testWidgets('a valid phone requests an OTP and advances to the OTP screen', (tester) async {
    final fakeApi = _FakeAuthApi();
    await tester.pumpWidget(_wrap(fakeApi));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final field = find.byType(TextFormField).first;
    await tester.enterText(field, '+7 700 123 45 67');
    await tester.tap(find.text('Continue'));
    // Not pumpAndSettle: OtpScreen starts a Timer.periodic resend countdown
    // the moment it's pushed, which never "settles" — a bounded pump lets
    // the push transition finish without waiting on it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeApi.lastRequestedPhone, '+7 700 123 45 67');
    expect(find.text('Verification code'), findsOneWidget);
  });

  testWidgets('shows a readable error when the phone number is rejected', (tester) async {
    final fakeApi = _FakeAuthApi()..errorOnRequest = const AuthException(AuthErrorKey.invalidPhoneNumber);
    await tester.pumpWidget(_wrap(fakeApi));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '+7 700 123 45 67');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid phone number.'), findsOneWidget);
    // Stays on the phone entry step.
    expect(find.text('Verification code'), findsNothing);
  });
}
